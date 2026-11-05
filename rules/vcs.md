# VCS / Commits

- Your user works with jj, not git, directly. Assume every repo should be jj-colocated. If one isn't yet, initialize it that way (`jj git init --colocate`) instead of falling back to plain git.
- In a colocated repo, a hook refuses `git push`/`git fetch`/other git write ops outright and names the jj equivalent in the refusal. Run that command and carry on; don't narrate the miss to the user ("oh right, we're using jj" or similar). Git stays read-only for you (`git log`, `git diff`, `git show` for inspection are fine).
- `git commit` is the exception and still asks the user, because a submodule gitlink bump (`git add <path>` plus `git commit`) is a write jj cannot make. Say in one line why git is needed before you run it.
- `jj commit -m "..."` is the direct analog of `git commit` (describes the current change and starts a new one). No staging step: jj tracks the working copy automatically; don't `git add` first.
- Use conventional commits for the description.
- Default to subject line only, no body. A body is the exception, not the norm.
- Add a body only when the *why* isn't inferable from the subject + diff, and then 1-2 short lines/bullets max, not prose paragraphs. Never restate *what* changed (the diff already shows that) or list changed files/functions (`jj diff`/`jj show` does that).
- If the rationale needs more than 1-2 lines, it isn't a commit-body candidate; see [[comments]] on where load-bearing decisions belong (a code comment or a long-lived doc/ADR with a pointer), not a wall of commit text nobody reopens.
- **Commit at natural batch points, not after every small step.** Multiple agents (background/code) often share the same checkout at once; committing on every step is noise and increases the odds of scooping up someone else's in-flight edits. Wait until a coherent chunk of work exists, then commit it. This still OVERRIDES the default "only commit when explicitly asked" behavior: no permission needed for a routine commit, just judgment on timing.
- **Before committing, always inspect the full working-copy diff first** (`jj status` / `jj diff`). jj has no staging area, so a bare `jj commit` captures everything currently modified, including files another agent is mid-edit on.
- **Scope the commit to your own batch.** If the diff contains anything you didn't do, commit only your paths (`jj commit -m "..." -- <paths>`), leaving the rest exactly as-is in the working copy. Never touch, stash, or sweep up someone else's uncommitted changes, not even to "clean up" or bundle them in.
- **Split by topic, not by convenience.** If your own batch turns out to span independent themes, make separate scoped commits rather than one mixed one.
- Still ASK before destructive or remote-visible actions: `jj git push` that force-moves a bookmark, `jj describe`/`jj squash` on a change already pushed (rewrites published history), `jj abandon`, `jj bookmark delete`, anything that affects shared/remote state. The auto-commit policy applies to local commits only. `jj op undo` is jj's safety net for local mistakes, not a license to skip asking before remote-visible ones.

# GitHub Writing Voice

Before drafting any GitHub issue, PR or comment on the user's behalf, load the
`prose-review` skill. Its "GitHub writing voice" section holds the writing-style
guide and the rules for using it.
