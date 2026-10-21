# extraStyles: style directories by name that every file is also checked
# against. Their fixtures are the caller's to run.
{
  pkgs,
  extraStyles ? {},
  ...
}: let
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

      ${pkgs.lib.concatStrings (pkgs.lib.mapAttrsToList (name: dir: ''
          cp -r ${dir} $out/styles/${name}
          sed -i 's/^BasedOnStyles = .*/&, ${name}/' $out/vale.ini
        '')
        extraStyles)}
    '';
in
  pkgs.writeShellApplication {
    name = "prose-check";
    runtimeInputs = [pkgs.vale];
    text = ''
      exec vale --config=${config}/vale.ini "$@"
    '';
  }
