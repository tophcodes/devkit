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

- `devShells.default` with just, watchexec, treefmt, prose-check and
  `devkit.packages`
- `formatter` and `checks.treefmt` via treefmt-nix: alejandra, deadnix and
  statix for Nix, shellcheck for shell, typos for spelling. Projects enable the
  formatters and linters for their languages under `treefmt.programs`
- `checks.prose`, which runs prose-check over the repository and fails on
  error-level alerts
- `checks.recipes`, which requires the standard justfile recipes
- `checks.test`, which runs `devkit.testCommand` in the build sandbox

typos reads a base configuration from devkit that allows German words its
English dictionary would "correct". A repository adds its own exceptions in
`_typos.toml`, which is merged over that base. Files that contain bad text on
purpose, such as linter fixtures, go into `devkit.fixtures`; prose-check and
typos skip them.

## prose-check

`packages.prose-check` is Vale with the Prose style (the rules from the
user-scope writing rules that a pattern can decide) and the Slop style from
vale-llm-slop. Its build runs the fixtures in `packages/prose-check/testdata`:
the clean files must raise no alert, and every Prose rule must fire on the dirty
ones.
