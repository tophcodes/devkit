{
  description = "Shared project foundation: dev shell, formatter, checks and templates";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    flake-parts,
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
          inherit nixpkgs flake-parts;
          devkit = self;
        };
        flake = (import (path + "/flake.nix")).outputs templateInputs;
      in
        flake;
    in {
      systems = ["x86_64-linux" "aarch64-linux"];
      imports = [
        flake-parts.flakeModules.flakeModules
        devkitModule
      ];

      flake = {
        flakeModules.default = devkitModule;
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
        checks.template-python =
          pkgs.linkFarmFromDrvs "template-python"
          (builtins.attrValues (templateFlake ./templates/python).checks.${system});
      };
    });
}
