# Proposal

## Why

devkit specifies its changes with OpenSpec (infra ADR-041), but its binding
decisions are still recorded in one ADR, `notes/adr/001-just-surface-shared-flake-foundation.md`.
A reader has to work through 168 lines of prose to learn what devkit
guarantees, and no OpenSpec change can state a delta against it. This change
distills the ADR into specifications once and removes it.

## What Changes

- Four capabilities record what ADR-001 decided, as requirements with
  scenarios.
- The ADR's context, criteria and rejected alternatives move to this change's
  `design.md`, so they stay readable in the change archive.
- `notes/adr/` is deleted. Documents that cite ADR-001 cite the specification
  instead.
- No behaviour of the module, the templates or the packages changes.

## Capabilities

### New Capabilities

- `command-surface`: the justfile recipes every repository offers and the check that enforces them.
- `quality-gates`: the formatters, linters and prose check that `nix flake check` runs in every repository.
- `templates`: what a devkit template contains and how devkit proves that each one works.
- `architecture`: where devkit's conventions apply, and the directory and Nix layout of a repository that uses devkit.

### Modified Capabilities

None; `openspec/specs/` is empty.

## Impact

- New: `openspec/specs/{command-surface,quality-gates,templates,architecture}/spec.md` after archive.
- Removed: `notes/adr/001-just-surface-shared-flake-foundation.md`.
- Updated references: `skills/devkit/SKILL.md` and the README, wherever they
  name ADR-001. The user-scope rule in the infra repository names ADR-001 too
  and is updated there.
