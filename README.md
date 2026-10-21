# devkit

Shared foundation for Toph's own repositories: a flake-parts module and one
template per language. The conventions it implements are in
[ADR-001](notes/adr/001-just-surface-shared-flake-foundation.md).

## New project

```sh
nix flake init -t git+ssh://git@github.com/tophcodes/devkit#python
```

## Existing project

Copy `flake.nix` from the template that matches the language: it declares
nixpkgs, flake-parts, import-tree and devkit, and imports every module under
`nix/` and `tools/`. Then configure devkit in `nix/devkit.nix`:

```nix
{inputs, ...}: {
  imports = [inputs.devkit.flakeModules.default];
  perSystem = {pkgs, ...}: {
    devkit.packages = [/* compilers, linters, test runners */];
    devkit.testCommand = "pytest";
  };
}
```

A project tool gets its module as `tools/<name>/default.nix`, next to its
source. Then add a justfile with the recipes `default`, `dev`, `test`, `fmt` and
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

## For agents

`skills/devkit` is a Claude Code skill with the procedures: a new project,
moving a repository onto devkit, adding a tool or a template, and handling a
failed `just check`. The infra repository links it into `~/.claude/skills`.
Each template carries an `AGENTS.md` for agents that read no user-scope rules.
