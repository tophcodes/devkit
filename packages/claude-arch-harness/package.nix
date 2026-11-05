{pkgs, ...}: let
  arch-check = pkgs.callPackage ../arch-check/package.nix {};
in
  pkgs.runCommand "claude-arch-harness" {
    nativeBuildInputs = [pkgs.shellcheck];
  } ''
    mkdir -p $out/.claude-plugin $out/hooks
    cp ${./plugin.json} $out/.claude-plugin/plugin.json
    cp ${./hooks/hooks.json} $out/hooks/hooks.json

    # The hooks resolve arch-check by absolute store path, not through PATH —
    # a hook runs in whatever environment the agent happens to have.
    for hook in ${./hooks}/*.sh; do
      name="$(basename "$hook")"
      if grep -q '@archCheck@' "$hook"; then
        substitute "$hook" "$out/hooks/$name" \
          --replace-fail '@archCheck@' '${arch-check}/bin/arch-check'
      else
        cp "$hook" "$out/hooks/$name"
      fi
      chmod +x "$out/hooks/$name"
    done

    # A placeholder that survived the loop would leave a hook calling a
    # literal "@archCheck@" at runtime.
    ! grep -rq '@archCheck@' $out/hooks

    shellcheck $out/hooks/*.sh

    cp -r ${./skills} $out/skills
  ''
