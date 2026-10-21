{pkgs, ...}: let
  slop = pkgs.fetchFromGitHub {
    owner = "Syntaf";
    repo = "vale-llm-slop";
    rev = "4dda3ec6426efa219e493d88396ed5c0471f7454";
    hash = "sha256-4B07P6W1bMRjelFVajWB54+G1NzK4j0Z5KKfSZ1+tfU=";
  };

  # The fixtures run on every build. The clean ones must raise no alert at any
  # level, and every Prose rule must fire at its own level on the dirty ones: a rule
  # nobody can trigger is dead, and a style that flags clean prose gets muted.
  config =
    pkgs.runCommand "prose-check-config" {
      nativeBuildInputs = [pkgs.vale pkgs.jq];
    } ''
      mkdir -p $out/styles
      cp ${./vale.ini} $out/vale.ini
      cp -r ${./styles/Prose} $out/styles/Prose
      cp -r ${slop}/styles/Slop $out/styles/Slop

      export HOME=$TMPDIR
      cd ${./testdata}
      vale --config=$out/vale.ini --no-exit --output=JSON \
        dirty.md clean.md dirty.rs clean.rs >$TMPDIR/alerts.json

      for clean in clean.md clean.rs; do
        jq -e --arg f "$clean" '(.[$f] // []) | length == 0' $TMPDIR/alerts.json >/dev/null || {
          echo "$clean raised alerts:"
          jq --arg f "$clean" '.[$f]' $TMPDIR/alerts.json
          exit 1
        }
      done

      for rule in ${./styles/Prose}/*.yml; do
        check="Prose.$(basename "$rule" .yml)"
        level="$(sed -n 's/^level: //p' "$rule")"
        jq -e --arg c "$check" --arg l "$level" \
          '[.["dirty.md"][] | select(.Check == $c and .Severity == $l)] | length > 0' \
          $TMPDIR/alerts.json >/dev/null || {
          echo "$check never fired as $level on dirty.md"
          exit 1
        }
      done

      jq -e '[.["dirty.rs"][] | select(.Check == "Prose.EmDash")] | length > 0' \
        $TMPDIR/alerts.json >/dev/null || {
        echo "Prose.EmDash missed the comment in dirty.rs"
        exit 1
      }
    '';

  # Besides the base styles, every style under a `.prose-check/styles/<Name>/`
  # directory above the checked path applies, the nearest one per name. A jj
  # workspace continues the search at its repository, so a session workspace
  # sees the styles of the checkout it was made from.
  prose-check = pkgs.writeShellApplication {
    name = "prose-check";
    runtimeInputs = [pkgs.vale pkgs.coreutils pkgs.gnused];
    text = ''
      # The first existing path argument decides for the whole call. Without
      # one, as for text on stdin, the working directory decides.
      target="$PWD"
      for arg in "$@"; do
        if [[ "$arg" != -* && -e "$arg" ]]; then
          target="$arg"
          break
        fi
      done

      declare -A found=()
      dir="$(realpath -m "$target")"
      [[ -d "$dir" ]] || dir="$(dirname "$dir")"
      while :; do
        for style in "$dir"/.prose-check/styles/*/; do
          [[ -d "$style" ]] || continue
          name="$(basename "$style")"
          [[ -v "found[$name]" ]] || found[$name]="''${style%/}"
        done
        if [[ -f "$dir/.jj/repo" ]]; then
          repo="$(<"$dir/.jj/repo")"
          [[ "$repo" == /* ]] || repo="$dir/.jj/$repo"
          dir="$(dirname "$(dirname "$(realpath -m "$repo")")")"
          continue
        fi
        [[ "$dir" == / ]] && break
        dir="$(dirname "$dir")"
      done

      if [[ ''${#found[@]} -eq 0 ]]; then
        exec vale --config=${config}/vale.ini "$@"
      fi

      tmp="$(mktemp -d)"
      trap 'rm -rf "$tmp"' EXIT
      mkdir "$tmp/styles"
      ln -s ${config}/styles/* "$tmp/styles/"
      names=""
      for name in "''${!found[@]}"; do
        # A local style cannot replace a base style of the same name.
        [[ -e "$tmp/styles/$name" ]] && continue
        ln -s "''${found[$name]}" "$tmp/styles/$name"
        names+=", $name"
      done
      sed "s/^BasedOnStyles = .*/&$names/" ${config}/vale.ini >"$tmp/vale.ini"
      vale --config="$tmp/vale.ini" "$@"
    '';
  };
in
  # A local style applies in its repository, in a jj workspace of it and to
  # text on stdin from inside it, and nowhere else.
  pkgs.runCommand "prose-check" {
    nativeBuildInputs = [prose-check];
    meta.mainProgram = "prose-check";
  } ''
    export HOME=$TMPDIR
    mkdir -p repo/.jj/repo repo/.prose-check/styles/Local repo/sub workspace/.jj elsewhere
    printf 'extends: existence\nmessage: "%%s"\nlevel: error\ntokens:\n  - frobnicate\n' \
      > repo/.prose-check/styles/Local/Word.yml
    echo "$TMPDIR/repo/.jj/repo" > workspace/.jj/repo
    for dir in repo/sub workspace elsewhere; do
      echo "We frobnicate the queue." > $dir/text.md
    done

    fires() { prose-check --no-exit --output=line "$@" | grep -q Local.Word; }
    fires repo/sub/text.md || { echo "local style missed its repository"; exit 1; }
    fires workspace/text.md || { echo "local style missed a jj workspace"; exit 1; }
    ! fires elsewhere/text.md || { echo "local style fired outside its repository"; exit 1; }
    (cd repo/sub && echo "We frobnicate." | fires --ext=.md) || {
      echo "local style missed stdin inside its repository"
      exit 1
    }

    mkdir -p $out/bin
    ln -s ${prose-check}/bin/prose-check $out/bin/prose-check
  ''
