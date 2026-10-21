{inputs, ...}: {
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
}
