---
name: jj-commit
description: >-
  Triage and commit whatever is sitting uncommitted in the current jj working
  copy. Use when the user runs /jj-commit, asks "what's uncommitted", "clean
  up the working copy", "commit this batch", or has leftover changes they no
  longer remember the context for. Groups the diff into logical bundles by
  reading the actual changes (not just directory), proposes a conventional
  commit message per bundle, and only commits after the user confirms the
  bundle plan. Leaves anything ambiguous or clearly foreign uncommitted rather
  than guessing.
---

# jj-commit

Cleans up an uncommitted working copy: figure out what's actually in it,
group it into sensible commits, and land each bundle with a message that
explains it — without sweeping in changes that turn out to belong to someone
else's in-flight work (see [[vcs]] on why: this checkout is often shared
between concurrent agents, and jj has no staging area — a bare `jj commit`
takes everything).

## Flow

1. **Inspect.** Run `jj status` for the file list, then `jj diff` for full
   content. If the working copy is empty, say so and stop.

2. **Bundle by meaning, not by folder.** Read the actual diff hunks and group
   files into logical commits — same feature, same fix, same refactor. Two
   files in the same directory can belong to different bundles; two files in
   different directories can belong to the same one. Bundling is per-file
   (`jj commit` splits at file granularity, not hunk granularity) — if a
   single file visibly mixes two unrelated changes, flag it rather than
   silently picking one bundle; suggest the user run `jj split -i` on it
   interactively.

3. **Flag what you can't place.** If a file's purpose isn't inferable from
   the diff (stale scratch edits, something mid-refactor, output that looks
   like it belongs to a different task entirely), don't force it into a
   bundle. Call it out as "unclear, leaving uncommitted" — that's the whole
   point of this skill existing.

4. **Draft messages.** One conventional-commit subject line per bundle,
   following [[vcs]]: no body unless the *why* genuinely isn't inferable from
   subject + diff, and even then 1-2 lines max.

5. **Show the plan, get one confirmation.** Present all bundles together —
   files + message each, plus the flagged/unclear leftovers — before
   touching anything. Don't commit on a maybe. Adjust on feedback.

6. **Execute in sequence.** For each confirmed bundle:
   `jj commit -m "<message>" -- <paths>`. Each commit only takes its own
   paths; everything else stays in the working copy for the next bundle (or
   stays uncommitted if flagged).

7. **Report what's still sitting there.** After committing the confirmed
   bundles, state plainly what — if anything — was left uncommitted and why,
   so it doesn't silently disappear into "handled".

## Guardrails

- Never `jj describe`/`jj squash` anything already pushed, never
  `jj git push`, never `jj abandon` — this skill only creates new local
  commits from the current working copy.
- Never guess your way through a file you can't explain — leaving it
  uncommitted is always the safe default.
- Re-run `jj status` if the session was idle for a while before executing —
  another agent may have changed the working copy since step 1.
