{
  description = "Shared project foundation: dev shell, formatter, checks and templates";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Only the template checks use it; projects declare it themselves.
    import-tree.url = "github:vic/import-tree";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    flake-parts,
    import-tree,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} ({flake-parts-lib, ...}: let
      devkitModule = flake-parts-lib.importApply ./modules/devkit.nix {localInputs = inputs;};

      # Evaluates a template's flake with this checkout as its devkit input, so
      # `nix flake check` here builds every template offline.
      templateFlake = path: let
        templateInputs = {
          self =
            flake
            // {
              outPath = path;
              inputs = templateInputs;
            };
          inherit nixpkgs flake-parts import-tree;
          devkit = self;
        };
        flake = (import (path + "/flake.nix")).outputs templateInputs;
      in
        flake;
    in {
      imports = [
        flake-parts.flakeModules.flakeModules
        devkitModule
      ];

      flake = {
        flakeModules.default = devkitModule;
        # Builds a Claude Code plugin; `mkClaudePlugin pkgs {name, src, runtimeInputs}`.
        lib.mkClaudePlugin = import ./lib/mk-claude-plugin.nix;
        modules.homeManager.claude = flake-parts-lib.importApply ./modules/claude.nix {localInputs = inputs;};
        # Links the herdr workbench from a devkit checkout; see herdr/README.md.
        modules.homeManager.herdr = ./modules/herdr.nix;
        # A machine the workbench's tabs run on: hx, jj, git, the status hooks
        # and optionally the boot unit for herdr-core.
        modules.nixos.herdr = flake-parts-lib.importApply ./modules/herdr-machine.nix {localInputs = inputs;};
        # Helix with the diff-base commands and the stale indicator the workbench uses.
        overlays.helix = import ./packages/helix/overlay.nix;
        templates.python = {
          path = ./templates/python;
          description = "Python project with pytest and ruff";
        };
      };

      perSystem = {
        pkgs,
        system,
        ...
      }: {
        packages = let
          mkClaudePlugin = import ./lib/mk-claude-plugin.nix pkgs;
        in rec {
          prose-check = pkgs.callPackage ./packages/prose-check/package.nix {};
          claude-statusline = pkgs.callPackage ./packages/claude-statusline/package.nix {};
          claude-herdr-status = pkgs.callPackage ./packages/claude-herdr-status/package.nix {};
          system-diff = pkgs.callPackage ./packages/system-diff/package.nix {};
          inherit ((pkgs.extend self.overlays.helix)) helix;
          arch-check = pkgs.callPackage ./packages/arch-check/package.nix {};
          claude-arch-harness = pkgs.callPackage ./packages/claude-arch-harness/package.nix {inherit mkClaudePlugin arch-check;};
          claude-jj-guard = pkgs.callPackage ./packages/claude-jj-guard/package.nix {inherit mkClaudePlugin;};
          claude-prose-guard = pkgs.callPackage ./packages/claude-prose-guard/package.nix {inherit mkClaudePlugin prose-check;};
        };
        # The style rules quote the phrases they forbid.
        devkit.fixtures = ["**/testdata/**" "packages/prose-check/styles/**"];

        checks.template-python =
          pkgs.linkFarmFromDrvs "template-python"
          (builtins.attrValues (templateFlake ./templates/python).checks.${system});
      };
    });
}
