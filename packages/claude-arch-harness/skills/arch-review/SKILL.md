---
name: arch-review
description: Use after writing an implementation plan or spec and before executing it, to collect the architecture decisions the plan makes and check them against existing decision records. Also use when a hook says a plan or spec was written, or when the user asks whether a plan crosses an architectural boundary.
---

# Architecture review of a plan

A plan looks like 90% method bodies because the architecture *is* the other
10% — scattered across forty tasks and therefore unreadable. This skill
de-scatters it, then checks the result against what was already decided.

Two stages. Stage 1 always runs and is usually silent. Stage 2 only runs if
stage 1 found something.

## Stage 1 — detector

Read the plan or spec. For each task, ask whether it touches any of these.
Nothing else counts as architecture; everything else is implementation detail.

| Category | What to look for |
|---|---|
| Manifest | `go.mod`, `pyproject.toml`, `Cargo.toml`, `dune-project`, `*.opam`, `Gemfile`, `package.json`, `flake.nix` |
| New module | a directory that does not exist yet |
| Public interface | `type X interface`, `pub trait`, exported `pub` in `lib.rs`, `Protocol`/ABC/`__all__`, a new `.mli`, a Rails concern |
| Schema / wire | migrations, `db/migrate/`, Alembic, `*.proto`, a changed on-disk or on-wire format |
| Process boundary | new `cmd/`, `[[bin]]`, `tokio::spawn`, Celery task, ActiveJob/Sidekiq worker, cron, queue |
| Second way | a second implementation of something that already exists |

Inverse test for anything you are unsure about: **could it be deleted in one
afternoon without any other file noticing?** If yes, it is implementation
detail. Leave it out.

**No hits → say "keine Architekturgrenze berührt" and stop.** Do not invent
findings to look thorough. Most plans cross nothing.

**Hits → write them out**, one line each: what is being decided, and which
category it falls under. Aim for ten lines, not forty. This list is the
artifact the human reviews instead of the plan.

## Stage 2 — review against the record

Only if stage 1 found something.

First find out which shape the repo uses. Both answer the same three
questions; only the files differ.

**A decision store** — a directory or a single file; take the first of:

```
docs/adr/  ·  adr/  ·  decisions/  ·  docs/decisions/  ·  notes/adr/
docs/decisions.md  ·  DECISIONS.md
```

1. **Live records** — the files directly in that directory, or the entries in
   that file.
2. **The archive** — `<dir>/archive/` (superseded and rejected). This is the
   one people forget, and it is the one that pays: it holds the alternatives
   that were already weighed and thrown away. A single-file store has no
   archive; its rejected options are in git, read as below.
3. **`docs/constraints.md`** — the executable rules. A repo may keep all of
   them here rather than in record frontmatter; `arch-check --json` resolves
   which without you having to guess.

**A normative document** — the contract in present tense, overwritten in place.
`docs/architecture.md` is that document wherever it exists, no marker word
required; failing that, grep `docs/*.md` for "normative" and read `CLAUDE.md`
for the repo's doc policy. There:

1. **Live decisions** — the relevant section of `docs/architecture.md`,
   `docs/memory.md`, `CLAUDE.md`. Present tense, overwritten in place.
2. **Rejected alternatives** — two places. Inline in that same doc, phrased as
   "X is deliberately rejected" / "why Y and not Z" — the rationale that still
   applies stays present-tense. And in **git commit messages**, which such
   repos treat as the permanent store for the *why* of a change that landed:
   `git log -S '<term>' -- docs/` and `git log --grep '<term>'` are the archive
   here. Old versions of the doc reachable via `git log -p` are the rest.
3. **`docs/constraints.md`** — same as above.

A repo may run both at once — `docs/architecture.md` for how it works,
`docs/decisions.md` for why this and not that. Read both; neither supersedes
the other.

A missing `adr/` is not "nothing decided". It usually means the decisions were
folded into the normative doc, which is denser and more current than a stack of
records. Never re-decide something on the grounds that no ADR covers it.

Dispatch a subagent with those three as context and the stage 1 list as the
question. If subagents are unavailable, do it yourself in a separate pass —
but read the records first, do not answer from memory of the codebase.

For each decision in the list, answer exactly one of:

- **Already decided** — a live record covers this. Name it. The plan should
  follow it; adjust the plan, do not re-decide.
- **Contradicts** — a live record or constraint says otherwise. Name it and
  stop for the human.
- **Previously rejected** — the archive contains this option. Quote why it was
  rejected. This is the session-12 case: the same alternative resurfacing
  because nobody remembered it was already weighed.
- **Open** — genuinely new. Present it to the human with two options and a
  one-sentence consequence each, plus a recommendation.

## After the human decides

Write the decision down, then attach its check — and the check goes next to
its reasoning, not into a separate list:

In a **normative-document repo**, "writing it down" means editing the normative
doc in place, present tense, in the same commit as the code — and putting the
dead alternative in the commit message. Do not introduce an `adr/` directory
into such a repo; that is a policy the repo has already decided against, and
two live descriptions of one architecture is the failure this whole thing
exists to prevent. Checks go wherever that repo already keeps them — record
frontmatter or `docs/constraints.md`, whichever `arch-check --json` shows the
existing ones coming from. Do not start a second location.

In a **record repo**:

**If the decision gets a record** (write one whenever the rejected alternative
would cost real effort to re-derive in six months), the check goes into that
record's YAML frontmatter:

```yaml
---
id: 0003
title: Exakte Arithmetik statt Floating Point
status: accepted
checks:
  - desc: Keine Float-Literale im Geometrie-Kern
    run: "! rg -q '[0-9]+\\.[0-9]+' lib/geometry/*.ml"
---
```

The rule then cannot drift from its reasoning, archiving the record retires
the check in the same move, and `arch-check` names the file in the error — so
whoever breaks it has the route to the *why*. Follow the repo's existing ADR
prose format below the frontmatter; do not invent a new one.

**Only if there is no record worth writing** — a bare convention, no
trade-off to preserve — does it become one line in `docs/constraints.md`. That
file is the exception. If you are about to add to it, first ask whether an ADR
already covers this; the check probably belongs in that ADR's frontmatter.

Never edit an existing ADR to record a reversal. Supersede it: write the new
record, move the old file to `<dir>/archive/`, and delete or replace its
constraint line.
