#!/usr/bin/env bash
# Tests for the arch-harness hooks. Run: bash packages/claude-arch-harness/test.sh
# The hooks are driven with real event JSON on stdin and the real arch-check.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STOP_HOOK="$HERE/hooks/arch-stop.sh"
STATUS_HOOK="$HERE/hooks/arch-status.sh"
export ARCH_CHECK_BIN="${ARCH_CHECK_BIN:-$HERE/../arch-check/arch-check}"

pass=0
fail=0

mkproject() {
  local dir
  dir="$(mktemp -d)"
  if [[ "$1" != NOFILE ]]; then
    mkdir -p "$dir/docs"
    printf '%s\n' "$1" >"$dir/docs/constraints.md"
  fi
  printf '%s' "$dir"
}

# fire <hook> <projectdir> <session_id> -> sets $rc, $out, $err
fire() {
  local hook="$1" dir="$2" sid="$3"
  local event outfile errfile
  event="$(jq -nc --arg sid "$sid" --arg cwd "$dir" \
    '{session_id: $sid, cwd: $cwd, hook_event_name: "Stop"}')"
  outfile="$(mktemp)"
  errfile="$(mktemp)"
  rc=0
  printf '%s' "$event" |
    (cd "$dir" && CLAUDE_PROJECT_DIR="$dir" XDG_STATE_HOME="$dir/.state" "$hook") \
      >"$outfile" 2>"$errfile" || rc=$?
  out="$(cat "$outfile")"
  # shellcheck disable=SC2034 # part of the documented output, for tests that inspect stderr
  err="$(cat "$errfile")"
  rm -f "$outfile" "$errfile"
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

RED_RULE='no direct net/http outside internal/httpx
  check: test -f absent-marker'

GREEN_RULE='everything is fine
  check: true'

BROKEN_RULE='a rule with a typo in its check
  check: definitely-not-a-real-binary-xyz'

# ---------------------------------------------------------------- stop hook

t_stop_no_constraints_file() {
  local d
  d="$(mkproject NOFILE)"
  fire "$STOP_HOOK" "$d" s1
  expect_eq "stop/nofile: exit 0" 0 "$rc"
  expect_eq "stop/nofile: silent" "" "$out"
  rm -rf "$d"
}

t_stop_green() {
  local d
  d="$(mkproject "$GREEN_RULE")"
  fire "$STOP_HOOK" "$d" s1
  expect_eq "stop/green: exit 0" 0 "$rc"
  expect_eq "stop/green: silent" "" "$out"
  rm -rf "$d"
}

t_stop_red_blocks() {
  local d
  d="$(mkproject "$RED_RULE")"
  fire "$STOP_HOOK" "$d" s1
  expect_eq "stop/red: exit 0" 0 "$rc"
  expect_eq "stop/red: decision is block" block "$(printf '%s' "$out" | jq -r '.decision // ""')"
  expect_contains "stop/red: reason carries the rule text" \
    "no direct net/http outside internal/httpx" "$(printf '%s' "$out" | jq -r '.reason // ""')"
  rm -rf "$d"
}

t_stop_gives_up_after_three() {
  local d i
  d="$(mkproject "$RED_RULE")"
  for i in 1 2 3; do
    fire "$STOP_HOOK" "$d" sloop
    expect_eq "stop/loop: attempt $i still blocks" block \
      "$(printf '%s' "$out" | jq -r '.decision // ""')"
  done
  fire "$STOP_HOOK" "$d" sloop
  expect_eq "stop/loop: attempt 4 does not block" "" \
    "$(printf '%s' "$out" | jq -r '.decision // ""')"
  expect_contains "stop/loop: attempt 4 warns the user instead" \
    "no direct net/http outside internal/httpx" \
    "$(printf '%s' "$out" | jq -r '.systemMessage // ""')"
  rm -rf "$d"
}

t_stop_counter_is_per_session() {
  local d i
  d="$(mkproject "$RED_RULE")"
  for i in 1 2 3 4; do
    fire "$STOP_HOOK" "$d" sessionA
  done
  fire "$STOP_HOOK" "$d" sessionB
  expect_eq "stop/counter: a fresh session blocks again" block \
    "$(printf '%s' "$out" | jq -r '.decision // ""')"
  rm -rf "$d"
}

t_stop_broken_check_does_not_block() {
  # The whole point of arch-check's exit 2: a typo must not trap the agent.
  local d
  d="$(mkproject "$BROKEN_RULE")"
  fire "$STOP_HOOK" "$d" s1
  expect_eq "stop/broken: exit 0" 0 "$rc"
  expect_eq "stop/broken: does not block" "" "$(printf '%s' "$out" | jq -r '.decision // ""')"
  expect_contains "stop/broken: warns the user" "Check kaputt" \
    "$(printf '%s' "$out" | jq -r '.systemMessage // ""')"
  rm -rf "$d"
}

t_stop_prunes_stale_counters() {
  local d stale
  d="$(mkproject "$GREEN_RULE")"
  mkdir -p "$d/.state/arch-harness/attempts"
  stale="$d/.state/arch-harness/attempts/ancient-session"
  echo 3 >"$stale"
  touch -d '25 hours ago' "$stale"
  fire "$STOP_HOOK" "$d" s1
  if [[ -e "$stale" ]]; then
    no "stop/prune: counter older than 24h removed" "still present"
  else
    ok "stop/prune: counter older than 24h removed"
  fi
  rm -rf "$d"
}

# ------------------------------------------------------------- status hook

t_status_no_constraints_file() {
  local d
  d="$(mkproject NOFILE)"
  fire "$STATUS_HOOK" "$d" s1
  expect_eq "status/nofile: exit 0" 0 "$rc"
  expect_eq "status/nofile: silent" "" "$out"
  rm -rf "$d"
}

t_status_reports_drift() {
  local d
  d="$(mkproject "$RED_RULE

$GREEN_RULE")"
  fire "$STATUS_HOOK" "$d" s1
  expect_eq "status: exit 0" 0 "$rc"
  expect_eq "status: event name" SessionStart \
    "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.hookEventName // ""')"
  expect_contains "status: additionalContext carries the count" "1/2 rot" \
    "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext // ""')"
  rm -rf "$d"
}

# ---------------------------------------------------------------- driver

for t in $(declare -F | awk '$3 ~ /^t_/ {print $3}'); do
  printf '%s\n' "$t"
  "$t"
done

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
