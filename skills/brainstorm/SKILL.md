---
name: brainstorm
description: Use at the start of any open-ended idea, question, or plan — including when it is not yet clear whether anything will be built at all. Covers software, infrastructure, and plain decisions (tool choice, purchase, approach). Explores intent first, then picks a domain module and an output level, so a five-minute thought does not turn into a spec and a plan.
---

# Brainstorming before the shape is known

Most brainstorming skills assume the answer is code and the output is a spec
plus a plan. That assumption is wrong often enough to be expensive: it turns a
question into a document, and a fifty-line change into a task list.

This skill separates two things that get conflated — *what kind of thing is
this* and *how much artefact does it deserve*.

## Step 1 — Explore, domain-free

Ask questions one at a time. Multiple choice where it fits, open where it
doesn't. Do **not** assume the outcome is software, and do not start
classifying yet.

What you are trying to learn:

- What is the actual problem behind the stated request?
- How settled is the user's picture? Sondierung and specification sound
  similar and need opposite treatment.
- What would make this a success — and what would make it not worth doing?
- Is anything already decided that this must live with?

If the request spans several independent subsystems, say so now and help split
it before refining any detail. Each piece then gets its own pass.

## Step 2 — Triage on two axes

**Domain** — one of `code`, `infra`, `decision`, or none.

- `code` — software work: a feature, a fix, a refactor, a tool.
- `infra` — the fleet: NixOS, Nomad, networking, hosts, secrets, backups.
- `decision` — a choice with no artefact to build: tool, vendor, purchase,
  approach, whether to do the thing at all.
- none — the topic fits no module. Stay generic, keep using the questions
  above, and cap the level at 1.

**Level** — how much output this earns.

| Level | Output | For |
|---|---|---|
| 0 | nothing written | thinking out loud, a question, exploration that dead-ends |
| 1 | a note | the decision, the reasoning, what was rejected. No task list |
| 2 | a spec | what gets built, formats, acceptance criteria. Implementation starts straight from it |
| 3 | spec + plan | the plan is written in plan mode and saved under `docs/plans/` |

## Step 3 — Pick the level

Start at 1. Weigh these; do not score them.

**Raises it:**

- The executor will have no context — a fresh agent, another session, a future
  you who has forgotten this conversation.
- Several units with handoffs between them, where one gets an interface wrong.
- Hard to reverse: a migration, secrets, DNS, anything that can lose data.
- Real logic or maths risk, not just wiring things together.
- More than roughly a day of work.

**Lowers it:**

- Purely additive and locally reversible.
- The user already dictated the layout, the formats, the acceptance test — then
  the conversation *is* the spec and a plan would restate it.
- The user is visibly still sondering rather than building.

Level 3 is for the case where a plan carries information the spec cannot: task
order, interface handoffs, where the maths risk sits. If the plan would only
re-list what the spec already fixed, it is level 2.

## Step 4 — Announce it

One line, then continue. Not a question, not a paragraph:

> `code` / level 2 — layout and formats are already fixed, no logic risk, so a
> spec is enough and I'll implement straight from it.

Name the one signal that decided it. The user overturns it in a sentence if
it's wrong.

## Step 5 — Load the module

Read `modules/<domain>.md` from this skill's directory. It brings its own
questions, artefact formats and follow-on skills. Then run the conversation at
the chosen level.

## Re-triage

The level stays open until something is written. If a level-2 conversation
turns up a handoff that needs a plan, say so and go up. Going down is just as
valid: if the scope collapses, drop the artefact instead of writing it out of
momentum.

## Rules

- One question per message. Do not stack three questions and call it one.
- Never skip to implementation at level 2 or 3 before the user has agreed to
  the design.
- At level 0 there is no file. Do not write one "just to have it".
- Note and spec locations belong to the module. If none applies and no
  repository is involved, ask once where it should go rather than inventing a
  path.
