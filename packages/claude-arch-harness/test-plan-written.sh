#!/usr/bin/env bash
# Tests for the plan-written reminder hook.
# Run: bash packages/claude-arch-harness/test-plan-written.sh
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/hooks/arch-plan-written.sh"

pass=0
fail=0

# $1 = CONSTRAINTS | ADRDIR | BARE
mkproject() {
  local dir
  dir="$(mktemp -d)"
  case "$1" in
    CONSTRAINTS)
      mkdir -p "$dir/docs"
      printf 'a rule\n  check: true\n' >"$dir/docs/constraints.md"
      ;;
    ADRDIR) mkdir -p "$dir/docs/adr" ;;
  esac
  printf '%s' "$dir"
}

# fire <projectdir> <tool> <path> -> sets $rc, $out
fire() {
  local dir="$1" tool="$2" path="$3" event outfile
  event="$(jq -nc --arg tool "$tool" --arg path "$path" --arg cwd "$dir" \
    '{session_id: "t", cwd: $cwd, hook_event_name: "PostToolUse",
      tool_name: $tool, tool_input: {file_path: $path}}')"
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

ctx() { printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext // ""'; }

expect_silent() {
  # expect_silent <label> <kind> <tool> <path>
  local d
  d="$(mkproject "$2")"
  fire "$d" "$3" "$d/$4"
  if [[ -z "$out" ]]; then ok "$1"; else no "$1" "hook spoke up: $out"; fi
  rm -rf "$d"
}

expect_fires() {
  # expect_fires <label> <kind> <tool> <path>
  local d
  d="$(mkproject "$2")"
  fire "$d" "$3" "$d/$4"
  expect_contains "$1" "arch-review" "$(ctx)"
  rm -rf "$d"
}

# ---------------------------------------------------------------- tests

t_bare_project_stays_silent() {
  expect_silent "bare: no constraints, no adr dir" BARE Write "docs/plans/thing.md"
}

t_fires_on_a_plan_in_a_constrained_project() {
  local d
  d="$(mkproject CONSTRAINTS)"
  fire "$d" Write "$HOME/.claude/plans/some-plan.md"
  expect_eq "plan: exit 0" 0 "$rc"
  expect_eq "plan: event name" PostToolUse \
    "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.hookEventName // ""')"
  expect_contains "plan: names the skill" "arch-review" "$(ctx)"
  rm -rf "$d"
}

t_fires_when_only_adrs_exist() {
  # beloch and aleph-garden have ADRs but no constraints.md yet.
  expect_fires "adr-only: docs/adr is enough" ADRDIR Write "docs/plans/thing.md"
}

t_fires_on_specs() {
  expect_fires "spec: docs/superpowers/specs" CONSTRAINTS Write "docs/superpowers/specs/2026-07-28-thing.md"
  expect_fires "spec: named spec.md" CONSTRAINTS Write "docs/design-spec.md"
}

t_fires_on_edit_too() {
  expect_fires "edit: plans are edited, not only written" CONSTRAINTS Edit "docs/plans/thing.md"
}

t_ignores_ordinary_files() {
  expect_silent "ignore: source file" CONSTRAINTS Write "src/main.go"
  expect_silent "ignore: ordinary doc" CONSTRAINTS Write "docs/architecture.md"
  expect_silent "ignore: the constraints file itself" CONSTRAINTS Write "docs/constraints.md"
}

# ---------------------------------------------------------------- driver

for t in $(declare -F | awk '$3 ~ /^t_/ {print $3}'); do
  printf '%s\n' "$t"
  "$t"
done

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
