# architecture Specification

## Purpose
Records the layout constraints a repository takes on when it uses devkit, and which repositories devkit covers at all.

## Requirements

### Requirement: Scope of the convention
devkit's conventions SHALL apply to Toph's own repositories. Team repositories, such as HAUSGOLD's, SHALL keep their own tooling and receive no devkit files. Introduced by change `distill-adr-001`.

#### Scenario: A team repository
- **WHEN** an agent works in a team repository without a devkit input
- **THEN** it adds no justfile, template file or devkit input to that repository

### Requirement: Directory roles
A repository SHALL keep the product in `packages/<name>/` (or `crates/` in a Rust workspace), standalone programs that serve the project in `tools/<name>/`, and single-file glue without own dependencies or tests in `scripts/`. Introduced by change `distill-adr-001`.

#### Scenario: A tool
- **WHEN** a repository adds a label generator that does not ship with the product
- **THEN** its source and module are kept in `tools/label-generator/`, the flake exports it as `packages.label-generator` and `apps.label-generator`, and the justfile has a recipe of that name

#### Scenario: A script grows
- **WHEN** a script in `scripts/` gains its own dependencies or tests
- **THEN** it moves to `tools/<name>/`

### Requirement: Dendritic Nix layout
Every `.nix` file under `nix/`, `tools/` and `packages/` SHALL be a flake-parts module, imported by import-tree. `flake.nix` SHALL hold only the inputs and that import. Nix files that are not modules SHALL be kept in a directory whose name starts with `_`. Introduced by change `distill-adr-001`.

#### Scenario: A tool's module
- **WHEN** a repository adds the tool `importer`
- **THEN** its flake-parts module is `tools/importer/default.nix`, and deleting the tool removes one directory

#### Scenario: A helper that is not a module
- **WHEN** a module needs a plain Nix function from another file
- **THEN** that file is kept in a directory such as `nix/_lib/`, which import-tree skips

### Requirement: Services through devenv's flake module
A repository that needs services such as a database or long-running processes SHALL add them through devenv's flake-parts module and SHALL keep one flake and one lock file. Introduced by change `distill-adr-001`.

#### Scenario: A repository needs PostgreSQL
- **WHEN** a repository's tests need a running PostgreSQL
- **THEN** devenv's flake-parts module provides it, and the repository has no `devenv.yaml` or `devenv.lock`
