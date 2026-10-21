{
  description = "app";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    devkit = {
      url = "git+ssh://git@github.com/tophcodes/devkit";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "aarch64-linux"];
      imports = [inputs.devkit.flakeModules.default];

      perSystem = {pkgs, ...}: let
        # Runtime dependencies also go into pyproject.toml; nixpkgs provides them here.
        python = pkgs.python3.withPackages (ps: [ps.pytest]);
      in {
        devkit.packages = [python pkgs.ruff];
        devkit.testCommand = "pytest";
        treefmt.programs = {
          ruff-format.enable = true;
          ruff-check.enable = true;
        };
      };
    };
}
