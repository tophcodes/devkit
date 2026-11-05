#!/usr/bin/env bash
# PreToolUse hook: in a colocated repo the human drives with jj, so a git write
# from the agent is put to the human instead of running on its own. The prompt
# names the jj equivalent, which is the answer in every routine case; the human
# approves the rest, a submodule pointer bump for instance, which jj cannot do.
set -uo pipefail

input="$(cat)"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty')"
base="${cwd:-${CLAUDE_PROJECT_DIR:-}}"

cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"
[[ -n "$cmd" ]] || exit 0

# Resolve a path the way the shell would, against the directory the command
# starts in.
abspath() {
  case "$1" in
    /*) printf '%s' "$1" ;;
    *) printf '%s/%s' "${2:-.}" "$1" ;;
  esac
}

# Which version control owns a directory. Walk up until the first marker: a
# `.jj` means the human drives with jj and the guard applies, a lone `.git` is
# a plain clone and stays a git repo. A plain clone nested inside a jj
# repository is therefore left alone, which is what the vendored application
# checkouts below a workspace root are.
scope() {
  local dir="$1"
  while :; do
    [[ -d "$dir/.jj" ]] && {
      printf jj
      return
    }
    [[ -e "$dir/.git" ]] && {
      printf git
      return
    }
    [[ -z "$dir" || "$dir" == / ]] && {
      printf none
      return
    }
    dir="$(dirname "$dir")"
  done
}

# A heredoc body is data the command writes out, never a command that runs.
# CI workflow files and setup scripts are routinely written this way and carry
# git lines that belong to some other machine.
strip_heredocs() {
  awk '
    skip {
      t = $0
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", t)
      if (t == delim) skip = 0
      next
    }
    match($0, /<<-?[[:space:]]*["'"'"']?[A-Za-z_][A-Za-z0-9_]*/) {
      d = substr($0, RSTART, RLENGTH)
      sub(/^<<-?[[:space:]]*["'"'"']?/, "", d)
      delim = d
      skip = 1
    }
    { print }
  '
}

# How often a character occurs in a string.
count_char() {
  local rest="${1//[^$2]/}"
  printf '%s' "${#rest}"
}

# A git token only counts when the shell would run it: at the start, or after
# a separator. Everything else is an argument or prose.
command_position() {
  case "$1" in
    "" | ";" | "&&" | "||" | "|" | "(" | "{" | "&" | "!" | then | do | else | sudo | env | time | xargs) return 0 ;;
    *\; | *"&&" | *"||" | *"|" | *"(") return 0 ;;
  esac
  return 1
}

# Find the first `git` invocation and its subcommand, skipping global flags:
# tools call `git -C <path> rev-parse` constantly. Best-effort by design, as
# the registration already filters on Bash(git *), and a command this cannot
# parse falls through to the normal permission flow.
#
# The same pass collects where that invocation runs: a `cd` earlier in the
# command line moves it, an explicit `-C` wins over both. Line ends become
# separators so a newline opens a new command position.
cmd_scan="$(printf '%s' "$cmd" | strip_heredocs | awk '{printf "%s ; ", $0}')"
read -ra tokens <<<"$cmd_scan"
sub=""
rest=()
dir="$base"
prev=""
quote=""
for ((i = 0; i < ${#tokens[@]}; i++)); do
  tok="${tokens[i]}"

  # Inside a quoted string nothing runs, so wait for the closing quote. Only
  # the quote characters matter, the content does not.
  if [[ -n "$quote" ]]; then
    [[ "$tok" == *"$quote"* ]] && quote=""
    prev="$tok"
    continue
  fi

  if [[ "$tok" == cd && $((i + 1)) -lt ${#tokens[@]} ]]; then
    target="${tokens[i + 1]//[\"\']/}"
    [[ "$target" == -* ]] || dir="$(abspath "$target" "$dir")"
    prev="$tok"
    continue
  fi

  if [[ "$tok" == git ]] && command_position "$prev"; then
    j=$((i + 1))
    while ((j < ${#tokens[@]})); do
      case "${tokens[j]}" in
        -C)
          dir="$(abspath "${tokens[j + 1]//[\"\']/}" "$dir")"
          j=$((j + 2))
          ;;
        -c) j=$((j + 2)) ;;
        -*) j=$((j + 1)) ;;
        *) break ;;
      esac
    done
    ((j < ${#tokens[@]})) && sub="${tokens[j]}"
    for ((k = j + 1; k < ${#tokens[@]}; k++)); do
      case "${tokens[k]}" in
        ";" | "&&" | "||" | "|" | *\; | *"&&" | *"||") break ;;
      esac
      rest+=("${tokens[k]}")
    done
    break
  fi

  if (($(count_char "$tok" "'") % 2 == 1)); then
    quote="'"
  elif (($(count_char "$tok" '"') % 2 == 1)); then
    quote='"'
  fi
  prev="$tok"
done

[[ -n "$sub" ]] || exit 0

# Only colocated repos are our business. A plain git repo stays a git repo.
[[ "$(scope "$dir")" == jj ]] || exit 0

case "$sub" in
  # Read-only. Editors, build steps and direnv depend on these.
  log | diff | show | status | blame | ls-files | rev-parse | cat-file | describe | ls-remote | shortlog)
    exit 0
    ;;
  # Read-only plumbing. Review and tooling reach for these constantly, and a
  # missing one lands in the unknown-subcommand branch as a false alarm.
  grep | ls-tree | for-each-ref | rev-list | merge-base | check-ignore | show-ref | symbolic-ref | hash-object | interpret-trailers | version | archive)
    exit 0
    ;;
  # Writes the index, never history. Nix flakes only see tracked files, so
  # this is required before every build in this repo.
  add)
    exit 0
    ;;
  # Both create a repository of their own. That the target sits below a jj
  # repository says nothing about the repository being made, which is a plain
  # git one the agent then owns.
  init | clone)
    exit 0
    ;;
esac

# Read or write depending on the flags. The reading forms are what tooling
# calls to orient itself, so deciding on the subcommand name alone turns them
# all into prompts.
case "$sub" in
  remote)
    case "${rest[0]:-}" in
      "" | -v | --verbose | show | get-url) exit 0 ;;
    esac
    ;;
  config)
    for arg in "${rest[@]}"; do
      case "$arg" in
        get | list | --get | --get-all | --get-regexp | --list | -l) exit 0 ;;
      esac
    done
    ;;
  worktree)
    case "${rest[0]:-}" in
      list) exit 0 ;;
    esac
    ;;
  # `--cached` writes the index and leaves the working copy alone, which puts
  # it with `git add` above. It is also the only way to drop a submodule
  # gitlink: jj cannot represent a 160000 entry, so it can neither add nor
  # remove one. Without the flag this deletes files, and jj tracks those.
  rm)
    for arg in "${rest[@]}"; do
      [[ "$arg" == --cached ]] && exit 0
    done
    ;;
  branch)
    write=0
    listing=0
    skip_value=0
    for arg in "${rest[@]}"; do
      ((skip_value)) && {
        skip_value=0
        continue
      }
      case "$arg" in
        -d | -D | -m | -M | -c | -C | -f | -u | --delete | --move | --copy | --force | --unset-upstream | --edit-description | --set-upstream-to*) write=1 ;;
        -l | --list) listing=1 ;;
        --contains | --no-contains | --merged | --no-merged | --points-at | --format | --sort | --color) skip_value=1 ;;
        -*) ;;
        *) ((listing)) || write=1 ;;
      esac
    done
    ((write)) || exit 0
    ;;
  tag)
    write=0
    listing=0
    skip_value=0
    for arg in "${rest[@]}"; do
      ((skip_value)) && {
        skip_value=0
        continue
      }
      case "$arg" in
        -d | -D | -f | -a | -s | -m | --delete | --force | --annotate | --sign | --message*) write=1 ;;
        -l | --list) listing=1 ;;
        --contains | --no-contains | --merged | --no-merged | --points-at | --format | --sort) skip_value=1 ;;
        -*) ;;
        *) ((listing)) || write=1 ;;
      esac
    done
    ((write)) || exit 0
    ;;
esac

# A write whose jj equivalent is mechanical is denied, not asked. A denial
# goes back to the agent with the reason, so it reaches for the jj command
# itself; asking spends a human decision on a substitution that has one right
# answer.
decision=deny
case "$sub" in
  # jj has no submodule support, so bumping a gitlink pointer is committed with
  # git. That is the one routine write the human has to see.
  commit)
    decision=ask
    hint="jj commit, der Working Copy ist bereits ein Commit, jj describe setzt die Nachricht; nur ein Submodule-Gitlink-Bump braucht wirklich git"
    ;;
  checkout | switch) hint="jj new <rev> für einen neuen Change, jj edit <rev> um einen bestehenden zu bearbeiten" ;;
  reset) hint="jj abandon um den Change wegzuwerfen, jj undo um die letzte Operation zurückzunehmen" ;;
  restore) hint="jj restore" ;;
  rebase) hint="jj rebase -d <dest>" ;;
  merge) hint="jj new <rev1> <rev2>" ;;
  stash) hint="nicht nötig, der Working Copy ist schon ein Commit, jj new legt daneben einen neuen an" ;;
  push) hint="jj git push" ;;
  pull | fetch) hint="jj git fetch" ;;
  branch) hint="jj bookmark" ;;
  tag) hint="jj bookmark bzw. jj git push --bookmark" ;;
  remote) hint="jj git remote add/remove/set-url" ;;
  cherry-pick) hint="jj duplicate -d <dest>" ;;
  revert) hint="jj undo für die letzte Operation, jj backout für einen Commit" ;;
  rm | mv) hint="einfach im Dateisystem löschen bzw. verschieben, jj trackt den Working Copy automatisch" ;;
  # A git worktree below a colocated repo is a dead end: jj resolves back to
  # the main workspace, and the guard refuses the writes made inside it.
  worktree) hint="jj workspace add <pfad> für einen eigenen Working Copy, jj workspace forget zum Auflösen" ;;
  # Nothing to name in its place, so the human decides whether it reads or
  # writes.
  *)
    decision=ask
    hint="unbekanntes Subkommando, falls es liest gehört es in die Allowlist von git-readonly.sh"
    ;;
esac

jq -nc --arg sub "$sub" --arg hint "$hint" --arg decision "$decision" \
  '{hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: $decision,
      permissionDecisionReason: ("git " + $sub + " in einem colocated jj-Repo: " + $hint)
    }}'
