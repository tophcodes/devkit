# Home Manager module with the Claude Code setup shared across machines: the
# plugins, skills, commands and rules this repository ships, and the CLIs the
# plugins and skills call. Importing it is the switch.
{localInputs}: {
  lib,
  pkgs,
  ...
}: let
  src = localInputs.self;
  packages = localInputs.self.packages.${pkgs.stdenv.hostPlatform.system};
in {
  programs.claude-code = {
    enable = true;

    plugins = {
      arch-harness = packages.claude-arch-harness;
      jj-guard = packages.claude-jj-guard;
      prose-guard = packages.claude-prose-guard;
    };

    skills = lib.mapAttrs (name: _: src + "/skills/${name}") (builtins.readDir (src + "/skills"));
    commandsDir = src + "/commands";
  };

  # A subdirectory, so a machine keeps rules of its own next to these: Claude
  # Code reads rules/ recursively.
  home.file.".claude/rules/devkit".source = src + "/rules";

  # They run outside a session too: from a shell, from CI, from another agent.
  home.packages = [packages.arch-check packages.prose-check];
}
