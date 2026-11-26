# Spec Delta

## Purpose

Gives every repository that uses devkit the same commands for listing, developing, testing, formatting and checking, whatever toolchain runs underneath.

## ADDED Requirements

### Requirement: Standard recipes
Every repository that uses devkit SHALL have a justfile with the recipes `default`, `dev`, `test`, `fmt` and `check`. `default` lists all recipes, `dev` starts the development loop, `test` runs the tests, `fmt` formats all files, and `check` runs `nix flake check`.

#### Scenario: A reader lists the commands
- **WHEN** someone runs `just` in a repository that uses devkit
- **THEN** the output lists at least `default`, `dev`, `test`, `fmt` and `check`

#### Scenario: Optional recipes
- **WHEN** a repository has a build, run, deploy or clean step
- **THEN** it offers that step as a recipe named `build`, `run`, `deploy` or `clean`, next to any project-specific recipes

### Requirement: Missing recipes fail the check
`nix flake check` SHALL fail when the justfile lacks one of the standard recipes, and SHALL name the missing recipe.

#### Scenario: A recipe is missing
- **WHEN** a repository's justfile has no `dev` recipe
- **THEN** `nix flake check` fails with "justfile lacks the required recipe 'dev'"

### Requirement: The test loop evaluates no flake
`just test` SHALL run the test command inside the development shell that direnv loads, without evaluating the flake.

#### Scenario: Running the tests repeatedly
- **WHEN** a developer runs `just test` twice inside the direnv shell
- **THEN** neither run evaluates the flake

### Requirement: CI runs the local check
`just check` and any CI SHALL both run `nix flake check`. When a repository sets `devkit.testCommand`, `nix flake check` SHALL run that command as the check `test`, in the build sandbox without network access.

#### Scenario: The test command is set
- **WHEN** a repository sets `devkit.testCommand = "pytest"`
- **THEN** `nix flake check` builds a check named `test` that runs `pytest` on a copy of the repository

#### Scenario: The tests need their own derivation
- **WHEN** a repository leaves `devkit.testCommand` null
- **THEN** devkit defines no `test` check and the repository defines its own
