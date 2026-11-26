# templates Specification

## Purpose
Gives a new repository a known-working starting point per language, which imports the shared module instead of copying it.

## Requirements

### Requirement: One template per language
devkit SHALL export one flake template per supported language. Each template SHALL contain a flake that imports the devkit module, an `.envrc` with `use flake`, a justfile with the standard recipes, an `AGENTS.md` that names `just` as the entry point, and an OpenSpec configuration.

#### Scenario: Starting a Python project
- **WHEN** someone runs `nix flake init -t github:tophcodes/devkit#python`
- **THEN** the directory contains `flake.nix`, `.envrc`, `justfile`, `AGENTS.md` and `openspec/config.yaml`

### Requirement: Templates are built by devkit's own check
devkit's `nix flake check` SHALL instantiate every template with the current checkout as its devkit input and SHALL build all of the template's checks, without network access to the devkit repository.

#### Scenario: A template breaks
- **WHEN** a change to the devkit module makes a template's checks fail
- **THEN** devkit's own `nix flake check` fails on the check named `template-<language>`

### Requirement: Updates reach repositories through the input
The shared module SHALL be consumed as a flake input. A repository SHALL pick up changes to the module with `nix flake update devkit`, without copying files from a template.

#### Scenario: A new linter in the module
- **WHEN** devkit's module enables an additional linter and a repository runs `nix flake update devkit`
- **THEN** the repository's `nix flake check` runs that linter without any edit to the repository's files
