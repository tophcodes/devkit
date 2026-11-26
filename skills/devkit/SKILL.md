---
name: devkit
description: Set up or change the tooling of one of Toph's own repositories with devkit, the shared flake-parts module and templates. Use when starting a new project, moving an existing repository onto devkit, adding a tool under tools/, adding a template for a new language to devkit, or when `just check` fails on formatting, typos, statix, deadnix, shellcheck or prose-check. Not for HAUSGOLD or other team repositories, which keep their own tooling.
---

# devkit

devkit (`github:tophcodes/devkit`) gives every own
repository the same surface: a justfile with `default`, `dev`, `test`, `fmt`
and `check`, a dev shell from the flake, and `nix flake check` as the gate.
The decision and its reasons are ADR-001 in the devkit repository.

## New project

```sh
nix flake init -t github:tophcodes/devkit#python
```

Then rename the placeholder `app` (package directory, `pyproject.toml`,
`description` in `flake.nix`), run `direnv allow`, and `just check`.

`nix flake show github:tophcodes/devkit` lists the templates.
If the language has none, follow "Add a template" below first, or build the
repository by hand from the layout in the next section.

## Move an existing repository onto devkit

Read the repository's current flake, devenv and task-runner files first; keep
what it builds, change only how.

1. `flake.nix`: inputs nixpkgs, flake-parts, import-tree and devkit (with
   `inputs.nixpkgs.follows` and `inputs.flake-parts.follows`); outputs exactly

   ```nix
   outputs = inputs:
     inputs.flake-parts.lib.mkFlake {inherit inputs;}
     (inputs.import-tree (builtins.filter builtins.pathExists [./nix ./tools ./packages]));
   ```

2. `nix/devkit.nix`: import `inputs.devkit.flakeModules.default`, set
   `devkit.packages` (compiler, language tools, test runner),
   `devkit.testCommand`, and the language's formatters and linters under
   `treefmt.programs` (ruff-format and ruff-check, rustfmt).
   Biome goes under `treefmt.settings.formatter.biome` with `command`,
   `options = ["check" "--write" "--no-errors-on-unmatched"]` and `includes`:
   `treefmt.programs.biome` passes a generated `--config-path`, so the
   repository's `biome.json` never applies. Before the first commit, `nix fmt`
   on an existing repository must change no file.
3. Everything else the old flake defined (packages, apps, overlays) moves into
   modules under `nix/`, or into `tools/<name>/default.nix` for a tool.
4. `justfile` with the five required recipes. `test` calls the same command as
   `devkit.testCommand`; `check` is `nix flake check`.
5. `.envrc` is `# shellcheck shell=bash` plus `use flake`.
6. `nix fmt`, then `just check`, and fix what it reports.
7. From a devkit checkout, `just openspec-adopt <path>` adds the OpenSpec
   configuration. Distil existing ADRs or design notes into requirements with
   `/openspec-propose`.

`devkit.testCommand` runs in the build sandbox without network. When the tests
need fetched dependencies (cargo crates, npm packages), leave it null and
define `checks.test` with the language's builder (crane, buildNpmPackage)
instead.

A repository with services (a database, a queue) keeps devenv through its
flake-parts module. devkit has no integration for that yet; say so instead of
inventing one.

## Add a tool

A standalone program that serves the project goes to `tools/<name>/`, with its
own dependencies and tests, and its module next to it:

```nix
# tools/<name>/default.nix
{
  perSystem = {pkgs, ...}: {
    packages.<name> = /* build with src = ./. */;
  };
}
```

Add a recipe of the same name to the justfile
(`<name> *args:` calling `nix run .#<name> -- {{ args }}`). A tool that imports
the project's core library is a subcommand of the main program instead.
Nix files that are not modules go into a directory whose name starts with `_`.

## Add a template to devkit

1. `templates/<language>/` with `flake.nix` (copy the Python one),
   `nix/devkit.nix`, `justfile`, `.envrc`, `.gitignore`, `AGENTS.md` and the
   smallest project that has one passing test.
2. Register it in devkit's `flake.nix`: `templates.<language>` and
   `checks.template-<language>` (same shape as the Python entries).
3. `just check` in devkit builds the template's checks. Prove the check bites:
   break the template's test once and watch it fail.

## When `just check` fails

| Check | Fix |
|---|---|
| `treefmt` (formatting) | `just fmt`, then commit the result |
| `treefmt` (statix, deadnix, shellcheck) | fix the code; these do not rewrite |
| `treefmt` (typos) | fix the word; a real word typos gets wrong, often German, goes into `_typos.toml` under `[default.extend-words]` |
| `prose` | rewrite the sentence as a direct claim; the message names the rule |
| `recipes` | add the missing justfile recipe |
| `test` | the tests failed in the sandbox; run `just test` |

A file that contains bad text on purpose, such as linter fixtures, goes into
`devkit.fixtures`. Never add a file there to silence a finding in real text.
