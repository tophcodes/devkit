# devkit

Shared foundation for Toph's own repositories: a flake-parts module and one
template per language. The conventions it implements are in
[ADR-001](notes/adr/001-just-surface-shared-flake-foundation.md).

## New project

```sh
nix flake init -t git+ssh://git@github.com/tophcodes/devkit#python
```

## Existing project

Add the input and import the module:

```nix
inputs.devkit = {
  url = "git+ssh://git@github.com/tophcodes/devkit";
  inputs.nixpkgs.follows = "nixpkgs";
  inputs.flake-parts.follows = "flake-parts";
};

# inside flake-parts.lib.mkFlake
imports = [inputs.devkit.flakeModules.default];
perSystem = {pkgs, ...}: {
  devkit.packages = [/* compilers, linters, test runners */];
  devkit.testCommand = "pytest";
};
```

Then add a justfile with the recipes `default`, `dev`, `test`, `fmt` and
`check`; `nix flake check` fails while one of them is missing.

## What the module provides

- `devShells.default` with just, watchexec, treefmt and `devkit.packages`
- `formatter` and `checks.treefmt` via treefmt-nix, with alejandra enabled;
  projects enable the formatters for their languages under `treefmt.programs`
- `checks.recipes`, which requires the standard justfile recipes
- `checks.test`, which runs `devkit.testCommand` in the build sandbox
