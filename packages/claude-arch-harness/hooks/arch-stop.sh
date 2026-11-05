#!/usr/bin/env bash
# Stop hook: let the agent repair its own constraint violations before the
# human ever sees the diff. Silent unless something is red.
set -uo pipefail

ARCH_CHECK="${ARCH_CHECK_BIN:-@archCheck@}"
MAX_ATTEMPTS="${ARCH_STOP_MAX_ATTEMPTS:-3}"

input="$(cat)"
session_id="$(printf '%s' "$input" | jq -r '.session_id // "unknown"')"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty')"

project="${CLAUDE_PROJECT_DIR:-$cwd}"
[[ -n "$project" ]] || exit 0
[[ -f "$project/docs/constraints.md" ]] || exit 0

attempts_dir="${XDG_STATE_HOME:-$HOME/.local/state}/arch-harness/attempts"
mkdir -p "$attempts_dir"

# Counters are keyed by session and would otherwise accumulate forever.
now="$(date +%s)"
for f in "$attempts_dir"/*; do
  [[ -f "$f" ]] || continue
  mtime="$(stat -c %Y "$f" 2>/dev/null)" || continue
  if ((now - mtime > 86400)); then
    rm -f "$f"
  fi
done

rc=0
report="$(CLAUDE_PROJECT_DIR="$project" "$ARCH_CHECK" 2>&1 >/dev/null)" || rc=$?

# 0 = clean. 2 = a check could not run; blocking on broken tooling would trap
# the agent in a loop it cannot escape, so warn the human and let it stop.
case "$rc" in
  0) exit 0 ;;
  2)
    jq -nc --arg m "$report" '{systemMessage: $m}'
    exit 0
    ;;
esac

counter_file="$attempts_dir/$session_id"
attempts=0
[[ -f "$counter_file" ]] && attempts="$(cat "$counter_file" 2>/dev/null || echo 0)"
attempts=$((attempts + 1))
printf '%s\n' "$attempts" >"$counter_file"

# After MAX_ATTEMPTS the agent has demonstrably failed to satisfy the check.
# Blocking further would be an infinite loop, so hand the problem to the human.
if ((attempts > MAX_ATTEMPTS)); then
  jq -nc --arg m "$report" \
    '{systemMessage: ("arch-check bleibt rot nach mehreren Versuchen:\n" + $m)}'
  exit 0
fi

jq -nc --arg r "$report" '{decision: "block", reason: $r}'
