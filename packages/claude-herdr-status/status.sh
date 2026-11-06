#!/usr/bin/env bash
# Claude Code reports its state to herdr-core as OSC 7501, the Program
# Status Protocol: `ESC ] 7501 ; state=<state>:app=claude-code[:kind=<kind>] ESC \`.
# Core stores it per terminal, so herdr-app and every other client of the
# core API list the session as an agent.
#
# A hook has no controlling terminal, so the report goes to the
# pseudo-terminal Claude Code reads from: the first ancestor whose stdin is
# a /dev/pts device. Outside a herdr-core terminal (no HC_TERMINAL_ID) it
# writes nothing.
#
# The script also labels its terminal with the repository the session works
# in, because herdr reads a terminal's folder from the process, which stays
# where the session started, and ignores OSC 7. The explorer mods and the
# pane header read the labels:
# - `herdr.folder`: the repository of the session's start folder, then of
#   each file it writes. A `cd` to look around moves nothing.
# - `herdr.folders`: the last eight repositories written to, newest first,
#   separated by ":".
# - `herdr.bases`: `<repository>=<commit>` per repository written to,
#   separated by ":": where it stood before the session's first write. The
#   explorer diffs from there by default.
#
# Usage: claude-herdr-status <state> [kind], with the hook input on stdin.
state="$1"
kind="${2:-}"
input="$(cat || true)"
[ -n "${HC_TERMINAL_ID:-}" ] || exit 0

# The repository holding a folder: jj's root, else git's, else the folder.
repo_of() {
  (command -v jj >/dev/null && jj root --ignore-working-copy -R "$1" 2>/dev/null) \
    || git -C "$1" rev-parse --show-toplevel 2>/dev/null \
    || printf '%s\n' "$1"
}

event="$(jq -r '.hook_event_name // empty' <<<"$input" 2>/dev/null || true)"
tool="$(jq -r '.tool_name // empty' <<<"$input" 2>/dev/null || true)"
folder=""
case "$event:$tool" in
  SessionStart:*)
    cwd="$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null || true)"
    [ -z "$cwd" ] || folder="$(repo_of "$cwd")"
    ;;
  PostToolUse:Write | PostToolUse:Edit | PostToolUse:MultiEdit | PostToolUse:NotebookEdit)
    file="$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<<"$input" 2>/dev/null || true)"
    dir="$(dirname "$file")"
    [ -z "$file" ] || [ ! -d "$dir" ] || folder="$(repo_of "$dir")"
    ;;
esac
if [ -n "$folder" ] && command -v hc >/dev/null; then
  labels="$(hc get "$HC_TERMINAL_ID" --json 2>/dev/null | jq -c '.labels // {}' || echo '{}')"
  seen="$(jq -r '."herdr.folders" // empty' <<<"$labels")"
  folders="$(printf '%s\n%s\n' "$folder" "${seen//:/$'\n'}" | awk 'NF && !s[$0]++' | head -8 | paste -sd:)"
  set -- "herdr.folder=$folder" "herdr.folders=$folders"

  # The first write into a repository records where it stood before:
  # jj's @ from its last snapshot (@- when that was empty), git's HEAD.
  # --ignore-working-copy keeps jj from snapshotting the write just made.
  bases="$(jq -r '."herdr.bases" // empty' <<<"$labels")"
  if [ "$event" = PostToolUse ] && [[ ":$bases:" != *":$folder="* ]]; then
    base=""
    if command -v jj >/dev/null && [ -d "$folder/.jj" ]; then
      base="$(jj log -R "$folder" --ignore-working-copy --no-graph -r @ \
        -T 'if(empty, parents.map(|c| c.commit_id()).join(","), commit_id)' 2>/dev/null || true)"
    else
      base="$(git -C "$folder" rev-parse HEAD 2>/dev/null || true)"
    fi
    [ -z "$base" ] || set -- "$@" "herdr.bases=$folder=$base${bases:+:$bases}"
  fi
  hc label "$HC_TERMINAL_ID" "$@" >/dev/null 2>&1 || true
fi

pid="$PPID"
tty=""
while [ "$pid" -gt 1 ]; do
  target="$(readlink "/proc/$pid/fd/0" 2>/dev/null || true)"
  case "$target" in
    /dev/pts/*) tty="$target"; break ;;
  esac
  pid="$(ps -o ppid= -p "$pid" | tr -d ' ')"
  [ -n "$pid" ] || exit 0
done
[ -n "$tty" ] || exit 0

report="state=$state:app=claude-code"
[ -z "$kind" ] || report="$report:kind=$kind"
printf '\033]7501;%s\033\134' "$report" >"$tty" 2>/dev/null || true
