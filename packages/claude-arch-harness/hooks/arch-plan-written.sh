#!/usr/bin/env bash
# PostToolUse hook: a plan or spec just landed. Architecture decisions are made
# while writing those, scattered over dozens of tasks — this is the moment to
# collect them, not after the diff exists.
#
# A skill description only fires if the model notices. A hook fires because a
# file was written.
set -uo pipefail

input="$(cat)"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty')"
project="${CLAUDE_PROJECT_DIR:-$cwd}"
[[ -n "$project" ]] || exit 0

# Opt-in: the project either states its constraints or keeps decision records.
# Repos with ADRs but no constraints.md yet still deserve the review.
has_context=0
[[ -f "$project/docs/constraints.md" ]] && has_context=1
for d in docs/adr adr decisions notes/adr; do
  [[ -d "$project/$d" ]] && has_context=1
done
((has_context == 1)) || exit 0

path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')"
[[ "$path" == *.md ]] || exit 0

base="$(basename "$path")"
case "$path" in
  */plans/* | */specs/*) ;;
  *)
    case "$base" in
      *spec*) ;;
      *) exit 0 ;;
    esac
    ;;
esac

jq -nc --arg p "$base" \
  '{hookSpecificOutput: {
      hookEventName: "PostToolUse",
      additionalContext: ("Plan/Spec geschrieben (" + $p + "). Vor der Umsetzung die Architekturentscheidungen darin sammeln: Skill arch-review ausführen. Bei keinem Grenzübertritt ist er still.")
    }}'
