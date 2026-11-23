# Home Manager module with the Claude Code setup shared across machines: the
# plugins, skills, commands and rules this repository ships, and the CLIs they
# call. Importing it installs all of them;
# `devkit.claude.plugins.<name>.enable = false` turns a single plugin off.
{localInputs}: {
  config,
  lib,
  pkgs,
  ...
}: let
  src = localInputs.self;
  packages = localInputs.self.packages.${pkgs.stdenv.hostPlatform.system};
  cfg = config.devkit.claude;

  # name -> the CLIs the plugin calls, installed with it.
  plugins = {
    arch-harness = [packages.arch-check];
    jj-guard = [];
    prose-guard = [packages.prose-check];
  };

  enabled = lib.filterAttrs (name: _: cfg.plugins.${name}.enable) plugins;
in {
  options.devkit.claude.plugins =
    lib.mapAttrs (name: _: {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to install devkit's ${name} plugin.";
      };
    })
    plugins;

  config = {
    programs.claude-code = {
      enable = true;
      plugins = lib.mapAttrs (name: _: packages."claude-${name}") enabled;
      # Reading the openspec-skills output is import-from-derivation: evaluation
      # builds it first. It keeps the skill names in step with openspec without
      # a list here to maintain.
      skills =
        lib.mapAttrs (name: _: src + "/skills/${name}") (builtins.readDir (src + "/skills"))
        // lib.mapAttrs (name: _: "${packages.openspec-skills}/${name}") (builtins.readDir packages.openspec-skills);
      commandsDir = src + "/commands";
    };

    # A subdirectory, so a machine keeps rules of its own next to these: Claude
    # Code reads rules/ recursively.
    home.file.".claude/rules/devkit".source = src + "/rules";

    # The skills call prose-check too, prose-review among them. pt is how a
    # session runs a command that prompts on a terminal.
    home.packages = [packages.prose-check packages.pt] ++ lib.concatLists (lib.attrValues enabled);
  };
}
