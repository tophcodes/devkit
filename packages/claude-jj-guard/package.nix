{pkgs, ...}:
pkgs.runCommand "claude-jj-guard" {
  nativeBuildInputs = [pkgs.shellcheck];
} ''
  mkdir -p $out/.claude-plugin $out/hooks
  cp ${./plugin.json} $out/.claude-plugin/plugin.json
  cp ${./hooks/hooks.json} $out/hooks/hooks.json

  for hook in ${./hooks}/*.sh; do
    install -Dm755 "$hook" "$out/hooks/$(basename "$hook")"
  done

  shellcheck $out/hooks/*.sh
''
