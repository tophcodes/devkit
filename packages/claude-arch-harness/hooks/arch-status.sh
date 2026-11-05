#!/usr/bin/env bash
# SessionStart hook: state the drift as a fact, not an instruction. Ambient
# signal instead of an interrupt.
set -uo pipefail

ARCH_CHECK="${ARCH_CHECK_BIN:-@archCheck@}"

input="$(cat)"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty')"

project="${CLAUDE_PROJECT_DIR:-$cwd}"
[[ -n "$project" ]] || exit 0
[[ -f "$project/docs/constraints.md" ]] || exit 0

count="$(CLAUDE_PROJECT_DIR="$project" "$ARCH_CHECK" --count 2>/dev/null)"
[[ -n "$count" ]] || exit 0

jq -nc --arg c "Constraint-Checks (docs/constraints.md): $count" \
  '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $c}}'
