---
name: session-recap
description: >-
  Produce a standardized, persisted session recap and finish the session with a
  named merge commit. ONLY for the fleet repository at ~/infra. In any other
  repository, do not use this skill: summarize in prose and write nothing to
  disk. Inside ~/infra, use it whenever you are about to summarize what was done
  across a chunk of work: wrapping up a session, "here's what we did", "recap",
  "summarize the changes", end-of-session handoffs, or any moment you would
  otherwise print a bulleted "what changed" list. It writes the recap to
  docs/recaps/, gets the user's sign-off, and commits it, optionally tying the
  session off with a "Finish session <id>: <Title>" merge commit that carries
  both the work and the recap.
---

# Session Recap

## Scope: ~/infra only

This skill writes into the repository it runs in. It is meant for one
repository, the fleet repo at `~/infra`, whose history is a running log of
machine configuration and where a recap earns its place.

**Everywhere else, stop here.** Summarize the work as ordinary prose in the
reply and write no file. A recap doc in a project repository is a process
artifact: it carries a session identifier, it describes what happened rather
than what holds, and it goes stale the moment the code moves. Anything durable
in it belongs in an ADR, an issue, or the code.

Check before doing anything else: if the working directory is not inside
`~/infra`, this skill does not apply.

## Why it exists

The point of this skill: a session shouldn't end as an ephemeral chat message.
Every recap becomes a durable artifact in `docs/recaps/`. Where the session's
commits also get tied off with one self-describing merge commit,
`jj log -r 'main::'` reads like a changelog six months later, and each entry
links to a recap doc explaining the *why*.

So when you feel the urge to print a "here's everything we did" summary, stop,
and run this flow instead.

**This repo is jj with a colocated git dir.** A pre-commit hook rejects
`git commit` outright. Every write below goes through `jj`.

## The flow at a glance

1. **Build** the recap in the standard format (below).
2. **Show & confirm.** Display the actual doc content, ask "Is this accurate?"
   Iterate until the user says yes. Do not proceed to committing on a maybe.
3. **Write & commit** the doc to `docs/recaps/<id>-<slug>.md`.
4. **Optionally finish the session** with a merge commit named
   `Finish session <id>: <Title>`. This is a separate decision, not a
   consequence of writing the recap; see the guard below.

Steps 3–4 only happen after explicit confirmation in step 2.

## Identifiers

- **`<id>`** = `yyyymmdd-NN`, today's date plus a zero-padded 2-digit counter.
  Determine `NN` by scanning `docs/recaps/` for files matching `<today>-*.md` and
  taking `max(NN) + 1` (start at `01` if none today). Zero-padded decimal sorts
  cleanly; don't use hex (it sorts wrong past `0f`).
- **`<slug>`** = short kebab-case of the title (e.g. `pocket-id-hcl`).
- **Filename** = `<id>-<slug>.md`, e.g. `20260608-01-pocket-id-hcl.md`.
- **`<Title>`** = a human one-liner naming the session's theme.

## Recap format

Write exactly this structure. Frontmatter is machine-readable; the body is for humans.

```markdown
---
session: <id>
date: <yyyy-mm-dd>
title: <Title>
status: recorded          # or: merged, once a Finish-session commit exists
commits:
  - <short-sha> <commit subject>
  - <short-sha> <commit subject>
---

# <Title>

## Summary

One to three sentences: what this session set out to do and what state it left
things in. Lead with the outcome, not the process.

## Changes

| Commit | What |
|--------|------|
| `<short-sha>` | <one line, the why if non-obvious> |

## Caveats & follow-ups

- Anything fragile, deferred, or pre-existing that the reader should know.
- Manual steps the user still owes (deploys, DNS, secrets, dashboards).

## Pending

- Work explicitly left for a future session.
```

Keep it tight and honest, mirroring the level of the recap the user already liked:
a changes table keyed by commit, then caveats, then what's left. If a section is
empty, drop it rather than padding.

Populate `commits:` from the log, not from memory:

```bash
jj log -r 'main..@' --no-graph -T 'commit_id.short() ++ " " ++ description.first_line() ++ "\n"'
```

List only the session's own commits. Where a session ran alongside someone else's
work, say so in the caveats rather than claiming their commits.

## Confirmation (don't skip)

Show the user the rendered doc, the full Markdown with frontmatter included, and ask
plainly: **"Is this recap accurate?"** The recap is about to become permanent git
history, so the user is the source of truth on accuracy. Apply their corrections
and re-show until they confirm.

## Committing the recap (step 3)

In jj the working copy *is* a commit, so there is no staging step, and no way to
commit "just your file" by default. Check first what else is in there:

```bash
jj status
```

If the working copy holds only the recap, describe it and open a fresh one:

```bash
jj describe -m "docs(recap): session <id>"
jj new
```

If it also holds unrelated changes, which is likely since the user often keeps working
while the recap is being written, split the recap into its own commit and leave
everything else in the working copy, untouched:

```bash
jj split docs/recaps/<id>-<slug>.md -m "docs(recap): session <id>"
```

Never sweep someone else's in-flight edits into the recap commit.

## Finishing the session (step 4, optional)

Goal: a single merge commit whose message is `Finish session <id>: <Title>`,
bringing in *both* the session's code changes *and* the recap doc, so that
`jj log -r 'main::'` reads as a changelog.

### Guard: is a merge even the right move?

Check where `main` stands relative to the work:

```bash
jj log -r 'main..@' --no-graph -T 'commit_id.short() ++ " " ++ description.first_line() ++ "\n"'
```

Only proceed if that range is *this session's commits*. Do not merge when:

- `main` is many commits behind and the range carries unrelated older work:
  then merging is a repo-wide decision the user has to make deliberately, not a
  side effect of writing a recap.
- The range interleaves commits from someone working in parallel.

In both cases: write the recap, say plainly what the range contains, and ask.

### The merge

`jj new` with two parents creates the merge commit; moving a bookmark is not a
rewrite, so nothing is destroyed and `jj op log` can undo it.

```bash
jj bookmark create session/<id> -r @-        # park the session tip (@- = the last real commit)
jj new main session/<id> -m "Finish session <id>: <Title>"
jj bookmark set main -r @                    # main now points at the merge
jj new                                       # fresh working copy on top
```

### After merging

- Leave the `session/<id>` bookmark in place; it names the merge's second parent.
- Report the merge commit id and the recap path.
- Don't push unless the user asks (per repo git conventions).

## Notes

- `jj undo` reverses the last operation, and `jj op log` shows everything further
  back, so a wrong bookmark move is recoverable. That is not a licence to guess:
  confirm the range with the user first.
- This repo runs pre-commit hooks; if a hook fails for reasons unrelated to the
  change (e.g. a network-bound flake check), follow the repo's normal practice
  for that situation rather than abandoning the recap.
