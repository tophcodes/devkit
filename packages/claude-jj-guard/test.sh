#!/usr/bin/env bash
# Tests for the jj-guard hook. Run: bash packages/claude-jj-guard/test.sh
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/hooks/git-readonly.sh"

pass=0
fail=0

# $1 = "JJ" to create a colocated .jj, anything else for a plain directory
mkproject() {
  local dir
  dir="$(mktemp -d)"
  [[ "$1" == JJ ]] && mkdir -p "$dir/.jj"
  printf '%s' "$dir"
}

# fire <projectdir> <command> -> sets $rc, $out
fire() {
  local dir="$1" cmd="$2" event outfile
  event="$(jq -nc --arg cmd "$cmd" --arg cwd "$dir" \
    '{session_id: "t", cwd: $cwd, hook_event_name: "PreToolUse",
      tool_name: "Bash", tool_input: {command: $cmd}}')"
  outfile="$(mktemp)"
  rc=0
  printf '%s' "$event" | (cd "$dir" && CLAUDE_PROJECT_DIR="$dir" "$HOOK") >"$outfile" 2>/dev/null || rc=$?
  out="$(cat "$outfile")"
  rm -f "$outfile"
}

ok() {
  pass=$((pass + 1))
  printf '  ok   %s\n' "$1"
}
no() {
  fail=$((fail + 1))
  printf '  FAIL %s\n' "$1"
  [[ -n "${2:-}" ]] && printf '       %s\n' "$2"
}
expect_eq() {
  if [[ "$2" == "$3" ]]; then ok "$1"; else no "$1" "expected [$2], got [$3]"; fi
}
expect_contains() {
  if [[ "$3" == *"$2"* ]]; then ok "$1"; else no "$1" "[$2] not found in [$3]"; fi
}

decision() { printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // ""'; }
why() { printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecisionReason // ""'; }

expect_allowed() {
  # "allowed" means the hook stays out of it: no decision, normal permission flow.
  local d
  d="$(mkproject JJ)"
  fire "$d" "$2"
  if [[ -z "$out" ]]; then ok "$1"; else no "$1" "hook spoke up: $out"; fi
  rm -rf "$d"
}

expect_asked() {
  # expect_asked <label> <command> <substring expected in the reason>
  # Put to the human, because there is no jj command to name in its place.
  local d
  d="$(mkproject JJ)"
  fire "$d" "$2"
  if [[ "$(decision)" == ask ]]; then
    expect_contains "$1" "$3" "$(why)"
  else
    no "$1" "not asked: $out"
  fi
  rm -rf "$d"
}

expect_denied() {
  # expect_denied <label> <command> <substring expected in the reason>
  # Refused to the agent with the jj equivalent in the reason, so it retries
  # on its own instead of waking the human.
  local d
  d="$(mkproject JJ)"
  fire "$d" "$2"
  if [[ "$(decision)" == deny ]]; then
    expect_contains "$1" "$3" "$(why)"
  else
    no "$1" "not denied: $out"
  fi
  rm -rf "$d"
}

# ---------------------------------------------------------------- tests

t_no_jj_repo_is_none_of_our_business() {
  local d
  d="$(mkproject PLAIN)"
  fire "$d" "git commit -m x"
  expect_eq "no .jj: exit 0" 0 "$rc"
  expect_eq "no .jj: silent even for a write" "" "$out"
  rm -rf "$d"
}

t_reads_pass() {
  expect_allowed "read: git log" "git log --oneline -5"
  expect_allowed "read: git diff" "git diff HEAD~1"
  expect_allowed "read: git status" "git status"
  expect_allowed "read: git show" "git show abc123"
  expect_allowed "read: git blame" "git blame README.md"
  expect_allowed "read: git ls-files" "git ls-files"
  expect_allowed "read: git rev-parse" "git rev-parse --show-toplevel"
  expect_allowed "read: git cat-file" "git cat-file -p HEAD"
  expect_allowed "read: git describe" "git describe --tags"
}

t_global_flags_before_subcommand() {
  # Tools call `git -C <path> rev-parse` constantly; the flag must not hide the
  # subcommand. The path stays inside the project, so the guard still applies.
  expect_allowed "flags: git -C path status" "git -C sub status"
  expect_asked "flags: git -C path commit still asked" "git -C sub commit -m x" "jj commit"
}

t_nested_plain_clone_is_left_alone() {
  # Workspace roots keep vendored checkouts below them. Those are plain clones
  # with their own remote, and the human drives them with git.
  local d
  d="$(mkproject JJ)"
  mkdir -p "$d/vendor/lib/.git"

  fire "$d" "cd vendor/lib && git checkout -b feature"
  expect_eq "nested clone: cd into it, then a write" "" "$out"

  fire "$d" "git -C vendor/lib commit -m x"
  expect_eq "nested clone: reached via -C" "" "$out"

  fire "$d" "git commit -m x"
  expect_contains "nested clone: the root itself stays guarded" \
    "jj commit" "$(why)"

  rm -rf "$d"
}

t_nested_colocated_repo_is_guarded() {
  # A colocated repo below another one is still colocated.
  local d
  d="$(mkproject JJ)"
  mkdir -p "$d/nested/.git" "$d/nested/.jj"

  fire "$d" "cd nested && git commit -m x"
  expect_contains "nested colocated: still asked" "jj commit" "$(why)"
  expect_eq "nested colocated: asked, not denied" ask "$(decision)"

  rm -rf "$d"
}

t_writes_are_denied_with_the_jj_equivalent() {
  expect_denied "write: checkout" "git checkout main" "jj new"
  expect_denied "write: reset" "git reset --hard HEAD" "jj abandon"
  expect_denied "write: rebase" "git rebase main" "jj rebase"
  expect_denied "write: stash" "git stash" "nicht nötig"
  expect_denied "write: push" "git push origin main" "jj git push"
  expect_denied "write: fetch" "git fetch origin" "jj git fetch"
  expect_denied "write: worktree add" "git worktree add ../wt feature" "jj workspace add"
}

t_worktree_listing_is_a_read() {
  # Tooling orients itself with it, and it changes nothing.
  expect_allowed "flags: git worktree list" "git worktree list"
}

t_git_rm_cached_is_an_index_write() {
  # Dropping a submodule gitlink has no jj spelling: jj cannot represent one.
  expect_allowed "index: git rm --cached" "git rm --cached local/muster"
  expect_denied "write: git rm without --cached" "git rm old.txt" "jj trackt den Working Copy"
}

t_commit_stays_with_the_human() {
  # A gitlink pointer bump is committed with git, and jj cannot do it, so this
  # one write keeps its prompt.
  expect_asked "write: commit" "git commit -m x" "jj commit"
}

t_git_add_is_allowed() {
  # Not read-only, but nix flakes only see tracked files, and CLAUDE.md requires
  # `git add` before every build. It touches the index, never history.
  expect_allowed "index: git add" "git add packages/foo"
}

t_unknown_subcommand_is_asked() {
  # The allowlist is the contract: anything not known to be read-only is a write.
  expect_asked "unknown: git frobnicate" "git frobnicate" "git frobnicate"
}

t_non_git_commands_are_ignored() {
  expect_allowed "non-git: ls" "ls -la"
  expect_allowed "non-git: rg" "rg 'git commit' README.md"
}

t_compound_command_is_caught() {
  expect_asked "compound: cd && git commit" "cd sub && git commit -m x" "jj commit"
}

t_read_only_plumbing_passes() {
  # Review and tooling reach for these constantly. Every one of them showed up
  # as a prompt before it was listed.
  expect_allowed "plumbing: git grep" "git grep -n TODO"
  expect_allowed "plumbing: git ls-tree" "git ls-tree -r HEAD --name-only"
  expect_allowed "plumbing: git for-each-ref" "git for-each-ref --format='%(refname)'"
  expect_allowed "plumbing: git rev-list" "git rev-list --count HEAD"
  expect_allowed "plumbing: git merge-base" "git merge-base main HEAD"
  expect_allowed "plumbing: git check-ignore" "git check-ignore -q .superpowers"
  expect_allowed "plumbing: git show-ref" "git show-ref --verify refs/heads/main"
  expect_allowed "plumbing: git archive" "git archive origin/master | tar -x -C /tmp/x"
}

t_flag_sensitive_reads_pass() {
  expect_allowed "flags: git remote -v" "git remote -v"
  expect_allowed "flags: git branch --show-current" "git branch --show-current"
  expect_allowed "flags: git branch -a" "git branch -a | head"
  expect_allowed "flags: git branch --list pattern" "git branch --list '*emi*'"
  expect_allowed "flags: git tag listing" "git tag -l 'v*'"
  expect_allowed "flags: git config --get" "git config --get user.email"
}

t_flag_sensitive_writes_are_denied() {
  expect_denied "flags: git remote add" "git remote add fork git@example.invalid:x.git" "jj git remote"
  expect_denied "flags: git branch creates a ref" "git branch backup HEAD" "jj bookmark"
  expect_denied "flags: git branch -D" "git branch -D stale" "jj bookmark"
  expect_denied "flags: git tag creates a tag" "git tag v1.0.0" "jj bookmark"
  expect_asked "flags: git config sets a value" "git config user.email t@e" "unbekanntes Subkommando"
}

t_new_repositories_are_not_ours() {
  # Both make a repository of their own. The jj repository further up says
  # nothing about the one being created.
  expect_allowed "new repo: git init" "git init -q -b main ."
  expect_allowed "new repo: git clone" "git clone https://example.invalid/x.git vendor/x"
}

t_heredoc_bodies_are_data() {
  # A workflow file written out this way carries git lines that run on some
  # other machine, and used to prompt here.
  expect_allowed "heredoc: workflow file" \
    "cat > .github/workflows/x.yml <<'EOF'
run: |
  git config user.name bot
  git commit -m release
EOF"
}

t_git_inside_a_string_is_data() {
  expect_allowed "string: echoed prose" "echo \"the hook asks before git commit\""
  expect_allowed "string: after a separator" "echo 'x'; echo \"a; git push is asked\""
}

t_jj_driving_its_own_backend_passes() {
  expect_allowed "jj: git remote list" "jj git remote list"
  expect_allowed "jj: git push" "jj git push --bookmark main"
  expect_asked "jj: a bare git later in the line still counts" \
    "jj git fetch && git commit -m x" "jj commit"
}

# ---------------------------------------------------------------- driver

for t in $(declare -F | awk '$3 ~ /^t_/ {print $3}'); do
  printf '%s\n' "$t"
  "$t"
done

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
