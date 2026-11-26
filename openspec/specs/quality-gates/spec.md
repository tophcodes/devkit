# quality-gates Specification

## Purpose
Applies the same formatters and linters for code and prose to every repository that uses devkit, so that text an agent writes passes the same gate as code.

## Requirements

### Requirement: Code formatting and linting
The devkit module SHALL configure the formatter with alejandra, deadnix and statix for Nix files and shellcheck for shell scripts. `nix fmt` SHALL run them, and `nix flake check` SHALL fail when one of them reports an error.

#### Scenario: A statix finding
- **WHEN** a Nix file in the repository has a statix error
- **THEN** `nix flake check` fails

### Requirement: Spelling check
The formatter SHALL run typos in report-only mode. It SHALL accept the German words in devkit's base list, merge a repository's `_typos.toml` over that list, and skip encrypted `*.age` files.

#### Scenario: A repository-specific word
- **WHEN** a repository lists a host name that typos would correct under `[default.extend-words]` in `_typos.toml`
- **THEN** typos accepts that host name in that repository

#### Scenario: Encrypted secrets
- **WHEN** a repository contains `secrets/token.age`
- **THEN** typos does not read it

### Requirement: Prose check
`nix flake check` SHALL run prose-check over the repository's documents and code comments and SHALL fail on error-level alerts only. Warnings and suggestions SHALL NOT fail the check.

#### Scenario: An error-level alert
- **WHEN** a comment contains an em dash
- **THEN** the check `prose` fails and names the file and line

#### Scenario: A warning
- **WHEN** a document triggers only warning-level alerts
- **THEN** the check `prose` passes

### Requirement: Fixtures with bad text on purpose
A repository SHALL be able to list globs in `devkit.fixtures`. The prose check and typos SHALL skip files that match them. The default list SHALL cover `**/testdata/**` and `.prose-check/**`.

#### Scenario: A linter fixture
- **WHEN** a repository adds `tests/fixtures/**` to `devkit.fixtures`
- **THEN** neither prose-check nor typos reports findings in those files

### Requirement: Context-specific prose styles
prose-check SHALL apply the styles in a `.prose-check/styles/` directory to every file below that directory and to the jj workspaces of the repository that owns it. devkit SHALL own prose-check and its base styles.

#### Scenario: A team's vocabulary
- **WHEN** a repository keeps a style for its application names in `.prose-check/styles/`
- **THEN** prose-check applies that style in the repository and its workspaces, and nowhere else
