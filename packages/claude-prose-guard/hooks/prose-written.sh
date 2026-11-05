#!/usr/bin/env bash
# PostToolUse hook: a file was just written. Rules load once, at session start,
# and adherence decays over a long session. This fires on the write itself.
#
# Only the hits enter the context, never the rule text. A clean file costs
# nothing.
set -uo pipefail

input="$(cat)"
path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')"
[[ -n "$path" ]] || exit 0
[[ -f "$path" ]] || exit 0

# Suggestions stay out of the context: they are for a deliberate review.
hits="$(prose-check --minAlertLevel=warning --output=line "$path" 2>/dev/null)"
[[ -n "$hits" ]] || exit 0

count="$(printf '%s\n' "$hits" | grep -c .)"
shown="$(printf '%s\n' "$hits" | head -n 20)"

jq -nc --arg hits "$shown" --arg n "$count" --arg p "$path" \
  '{hookSpecificOutput: {
      hookEventName: "PostToolUse",
      additionalContext: ("prose-check flagged " + $n + " line(s) in " + $p +
        ". Fix them before moving on. Do not paraphrase around a flag: rewrite the sentence as a direct claim that carries the same information, or delete it if the flagged construction was all it carried.\n" + $hits)
    }}'
