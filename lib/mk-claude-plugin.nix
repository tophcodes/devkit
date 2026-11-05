# Builds a Claude Code plugin from Nix attributes. It writes plugin.json and
# hooks/hooks.json itself; each hook names its script, which becomes a
# writeShellApplication with runtimeInputs on PATH, and hooks.json calls it by
# store path. The build fails on a shellcheck finding.
#
#   mkClaudePlugin pkgs {
#     name = "example"; version = "0.1.0"; description = "...";
#     runtimeInputs = [pkgs.jq];
#     skills = ./skills;
#     hooks.PostToolUse = [{
#       matcher = "Write|Edit";
#       hooks = [{script = ./hooks/check.sh;}];
#     }];
#   }
#
# A hook entry takes the fields of hooks.json; `script` replaces `type` and
# `command`.
pkgs: {
  name,
  version,
  description,
  runtimeInputs ? [],
  hooks ? {},
  skills ? null,
}: let
  inherit (pkgs) lib;

  # writeShellApplication writes its own shebang above the text.
  withoutShebang = text: let
    lines = lib.splitString "\n" text;
  in
    if lib.hasPrefix "#!" (lib.head lines)
    then lib.concatStringsSep "\n" (lib.tail lines)
    else text;

  wrap = script: let
    bin = lib.removeSuffix ".sh" (baseNameOf script);
  in "${pkgs.writeShellApplication {
    name = bin;
    inherit runtimeInputs;
    # The hook scripts set these themselves and leave errexit off.
    bashOptions = ["nounset" "pipefail"];
    text = withoutShebang (builtins.readFile script);
  }}/bin/${bin}";

  # An empty `args` makes Claude Code run the command directly, without a
  # shell in between.
  hook = entry:
    {
      type = "command";
      command = wrap entry.script;
      args = [];
    }
    // removeAttrs entry ["script"];

  hooksJson = lib.mapAttrs (_: map (group: group // {hooks = map hook group.hooks;})) hooks;

  json = pkgs.formats.json {};
in
  pkgs.runCommand "claude-${name}" {} ''
    mkdir -p $out/.claude-plugin $out/hooks
    cp ${json.generate "plugin.json" {inherit name version description;}} $out/.claude-plugin/plugin.json
    cp ${json.generate "hooks.json" {hooks = hooksJson;}} $out/hooks/hooks.json
    ${lib.optionalString (skills != null) "cp -r ${skills} $out/skills"}
  ''
