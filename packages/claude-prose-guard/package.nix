{
  pkgs,
  prose-check,
  ...
}:
pkgs.runCommand "claude-prose-guard" {
  nativeBuildInputs = [pkgs.shellcheck];
} ''
  mkdir -p $out/.claude-plugin $out/hooks
  cp ${./plugin.json} $out/.claude-plugin/plugin.json
  cp ${./hooks/hooks.json} $out/hooks/hooks.json

  # The hooks resolve prose-check by absolute store path. A hook runs in
  # whatever environment the agent happens to have, so PATH is not dependable.
  for hook in ${./hooks}/*.sh; do
    name="$(basename "$hook")"
    substitute "$hook" "$out/hooks/$name" \
      --replace-fail '@proseCheck@' '${prose-check}/bin/prose-check'
    chmod +x "$out/hooks/$name"
  done

  ! grep -rq '@proseCheck@' $out/hooks

  shellcheck $out/hooks/*.sh
''
