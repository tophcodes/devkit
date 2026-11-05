#!/usr/bin/env bash
# PreToolUse hook: prose that leaves the machine without ever being a file.
# Issue and PR bodies, review comments, commit messages. The text sits in the
# command line, so it can be checked before the command runs.
#
# This one denies rather than comments: once the command has run, the text is
# published and a rewrite means an edit somebody can see.
set -uo pipefail

input="$(cat)"
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"
[[ -n "$cmd" ]] || exit 0

case "$cmd" in
  *"gh pr create"* | *"gh pr edit"* | *"gh pr comment"* | *"gh pr review"*) ;;
  *"gh issue create"* | *"gh issue edit"* | *"gh issue comment"* | *"gh issue close"*) ;;
  *"gh release create"*) ;;
  *"jj commit"* | *"jj describe"* | *"git commit"*) ;;
  *) exit 0 ;;
esac

# The escape hatch, for text that quotes someone else or quotes the patterns
# themselves.
case "$cmd" in
  *"prose-check: skip"*) exit 0 ;;
esac

# Only error-level alerts deny. The warning and suggestion rules never block
# on their own.
hits="$(printf '%s' "$cmd" | prose-check --ext=.md --minAlertLevel=error --output=line 2>/dev/null)"
[[ -n "$hits" ]] || exit 0

jq -nc --arg hits "$hits" \
  '{hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: ("prose-check refused this text before it went out. Rewrite the flagged sentences as direct claims and run the command again. Append \"prose-check: skip\" inside the command to override when the text quotes someone else.\n" + $hits)
    }}'
