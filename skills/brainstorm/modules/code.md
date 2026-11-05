# Module: code

Software work: a feature, a fix, a refactor, a tool.

The level chosen during triage governs everything here. A spec or a plan is
written only when the level calls for it; implementation never waits on both
by default.

## Ask about

- What already exists that this touches, and what patterns does it follow?
- Where are the seams? Which units talk to which, and across what interface?
- How do we know it works? A concrete acceptance test beats "it should work".
- Does anything here carry logic or maths risk, or is it wiring?
- Is the change additive, or does it replace something with live users/data?

Explore the codebase before proposing structure. Follow what is there. Fix
adjacent problems only where they block the work.

## Design for isolation

Each unit: one clear purpose, a defined interface, understandable and testable
on its own. If you cannot say what a unit does without describing its
internals, the boundary is wrong. Files that grow large are usually doing two
jobs.

## Output by level

**Level 0**: no file. Answer, sketch, move on.

**Level 1**: a short note recording what was decided and what was rejected.
Put it in the repository's docs directory. If no repository applies, ask once
where it goes.

**Level 2**: a spec at `docs/specs/YYYY-MM-DD-<topic>-design.md`.
It fixes what gets built, the formats, and the acceptance test. It does not
list tasks. Commit it, ask the user to review, then implement straight from it.

**Level 3**: the same spec, then a plan written in plan mode and saved at
`docs/plans/YYYY-MM-DD-<topic>.md`. Only when the plan carries something the
spec cannot: task order, interface handoffs between units, where the risk sits.

## Follow-on skills

- Write the failing test before the implementation code.
- `/code-review`: the diff, before merging.
- `arch-harness:arch-context`: when the change touches an area with existing
  architecture decisions, before writing the spec.

## Before writing a spec

Check the spec for placeholders, contradictions between sections, requirements
that read two ways, and scope that should have been split. Fix inline.
