# Command: Isolate this session in its own workspace

Create an isolated checkout to work in, without asking the user for help.

`EnterWorktree` and `git worktree` are denied in jj-colocated repos: the jj-guard
hook blocks `git commit`/`git push` inside a git worktree, and jj commands run
there resolve back to the user's default workspace, so a commit would swallow
their uncommitted changes. `jj workspace add` is the working equivalent.

## 1. Decide which mechanism applies

```bash
jj workspace root
```

Success means a jj repo (colocated or not): use the jj path below.
Failure means no jj repo: use `EnterWorktree` or `git worktree add` as normal,
and stop reading here.

## 2. Create the workspace

Name the workspace after the task, and put it beside the repo, never inside it.
A nested workspace ends up in the parent's own file tree.

```bash
repo=$(jj workspace root)
name=<task-slug>
jj workspace add --name "$name" "$repo/../$(basename "$repo")-$name"
```

The new working-copy commit shares the parents of the current one, so the
user's uncommitted edits stay behind in their checkout. To start from a
specific base instead, pass `-r main` (or whatever the trunk bookmark is).

## 3. Work there

**Everything from now on happens in the workspace directory.** Pass absolute
paths under it to Read/Edit/Write, and `cd` into it at the start of every Bash
command, because the shell working directory resets between calls.

A jj workspace has **no `.git`**, even when the main checkout is colocated.
Every `git` command fails there with "not a git repository". Use jj:

| instead of | run |
|---|---|
| `git status` / `git diff` / `git log` | `jj st` / `jj diff` / `jj log` |
| `git add` | nothing, jj tracks the working copy |
| `git commit -m` | `jj commit -m` |
| `git apply` | `patch -p1` |

Commits land in the shared repo and are visible from the user's checkout right
away. Push with `jj bookmark create <branch> -r @` then
`jj git push --bookmark <branch> --remote origin` (ask first, it is
remote-visible).

## 4. Clean up when the work is done

Committed and bookmarked work survives this; only the checkout goes away.

```bash
cd "$repo"
jj workspace forget "$name"
rm -rf "$repo/../$(basename "$repo")-$name"
```

Do this before reporting back, unless the user asked to keep the workspace.
Leaving it behind means jj keeps reporting a stale workspace in
`jj workspace list` forever.
