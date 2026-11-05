---
name: arch-context
description: Use before writing a spec, design doc, or brainstorming a feature, to surface which architecture decisions and constraints already apply to the area being changed. Also use when the user asks what has already been decided about a subsystem.
---

# What already applies here

Cheap, read-only, runs before the spec. Its job is to stop a spec from
re-deciding something that was decided months ago — which is how a project
ends up with two of everything.

## Do this

1. **What binds, first.** `arch-check --json` lists every active check with the
   file it comes from — that is the fastest complete picture, and it tells you
   where a repo keeps its checks without you having to know. Some put them in
   the `checks:` frontmatter of the decision records, some keep all of them in
   `docs/constraints.md`. Both are fine; `--json` flattens the difference.

2. **Then the reasoning.** Repos keep it in one of two shapes, and a repo may
   use both — find out which before reading anything.

   **A decision store**, whether a directory or a single file. Take the first
   that exists:

   ```
   docs/adr/  ·  adr/  ·  decisions/  ·  docs/decisions/  ·  notes/adr/
   docs/decisions.md  ·  DECISIONS.md
   ```

   From a directory, read only what is *directly* in it. Anything in
   `archive/` is no longer true and anything in `draft/` was never agreed —
   both stay out of this summary. Index tables (`README.md`, `000-*.md`) are
   the fast path: titles first, open only what looks relevant. From a single
   file, read the headings first and open only the entries that touch the
   area — same discipline, one file.

   **A normative document** carries the contract in present tense, overwritten
   in place. `docs/architecture.md` is that document wherever it exists — no
   marker word needed to confirm it. Failing that, look for a doc that calls
   itself normative in `docs/*.md` and read `CLAUDE.md` for the repo's stated
   doc policy; `docs/memory.md` and `CLAUDE.md` itself are the other usual
   carriers. Read the relevant section, not the file.

   The two coexist: a repo holding both `docs/architecture.md` and
   `docs/decisions.md` has split "how it works" from "why this and not that",
   and both are live.

   Do not treat a missing `adr/` as "nothing has been decided here". It
   usually means the opposite — the decisions were folded into the normative
   doc, which is denser and more current than a stack of records would be.

3. **Filter to the area.** A feature touching the storage layer does not need
   the decision about the license or the project name.

## Output

At most ten lines. Format:

```
Gilt hier schon:
- ADR-007  Nomad-Jobs sind vanilla HCL, kein Nix-DSL — Check grün (Ratchet ≤2)
- ADR-004  Jedes Volume eines Jobs ist als NixOS host volume deklariert — Check grün
```

Then one line naming what is **not** covered — the space the spec is actually
free to decide in. That line is the point of the whole exercise.

If nothing applies, say so in one line and move on. Do not pad.

## Do not

- Do not paste ADR bodies into the conversation. Titles and one clause each.
  A 90-line record in context is noise during design and poison during
  implementation.
- Do not read `archive/` here. It has exactly one legitimate reader and that
  is `arch-review`, which needs it to catch a rejected option resurfacing.
- Do not decide anything. This skill reports; the spec decides.
