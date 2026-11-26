# Tasks

## 1. Specifications

- [x] 1.1 Validate the change with `openspec validate distill-adr-001 --strict` and verify it reports no errors or warnings

## 2. Remove the ADR

- [x] 2.1 Delete `notes/adr/001-just-surface-shared-flake-foundation.md` and verify `notes/` no longer exists
- [x] 2.2 Point the README and `skills/devkit/SKILL.md` at `openspec/specs/` instead of ADR-001, and verify `rg -n 'ADR-001'` finds nothing outside `openspec/`

## 3. Integration

- [x] 3.1 Run `nix flake check` and verify it passes

## Workflow follow-up

- Archive the change with `openspec archive distill-adr-001` and verify `openspec list --specs` shows the four capabilities.
- Update the infra repository's user-scope rule `projects.md`, which names ADR-001.
