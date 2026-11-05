#!/usr/bin/env bash
# Tests for arch-check. Run: bash packages/arch-check/test.sh
# No test framework: arch-check itself must run with nothing but bash, jq, rg.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCH_CHECK="${ARCH_CHECK:-$HERE/arch-check}"

# The packaged binary carries yq; a raw checkout may not.
if ! command -v yq >/dev/null 2>&1; then
  yqbin="$(nix build --no-link --print-out-paths nixpkgs#yq-go 2>/dev/null)/bin"
  [[ -x "$yqbin/yq" ]] && export PATH="$yqbin:$PATH"
fi

pass=0
fail=0

# Each test gets a throwaway project dir. $1 = contents of docs/constraints.md,
# or the literal string NOFILE to omit it entirely.
mkproject() {
  local dir
  dir="$(mktemp -d)"
  if [[ "$1" != NOFILE ]]; then
    mkdir -p "$dir/docs"
    printf '%s\n' "$1" >"$dir/docs/constraints.md"
  fi
  printf '%s' "$dir"
}

# run <projectdir> [args...] -> sets $rc, $out, $err
run() {
  local dir="$1"
  shift
  local outfile errfile
  outfile="$(mktemp)"
  errfile="$(mktemp)"
  rc=0
  (cd "$dir" && CLAUDE_PROJECT_DIR="$dir" "$ARCH_CHECK" "$@") >"$outfile" 2>"$errfile" || rc=$?
  out="$(cat "$outfile")"
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
  # expect_eq <label> <expected> <actual>
  if [[ "$2" == "$3" ]]; then
    ok "$1"
  else
    no "$1" "expected [$2], got [$3]"
  fi
}

expect_contains() {
  # expect_contains <label> <needle> <haystack>
  if [[ "$3" == *"$2"* ]]; then
    ok "$1"
  else
    no "$1" "[$2] not found in [$3]"
  fi
}

# ---------------------------------------------------------------- tests

t_no_file() {
  local d
  d="$(mkproject NOFILE)"
  run "$d"
  expect_eq "no constraints.md: exit 0" 0 "$rc"
  expect_eq "no constraints.md: stdout empty" "" "$out"
  expect_eq "no constraints.md: stderr empty" "" "$err"
  rm -rf "$d"
}

t_satisfied() {
  local d
  d="$(mkproject 'every lib file has a header
  check: true')"
  run "$d"
  expect_eq "satisfied: exit 0" 0 "$rc"
  expect_eq "satisfied: stdout empty" "" "$out"
  expect_eq "satisfied: stderr empty" "" "$err"
  rm -rf "$d"
}

t_violated() {
  local d
  d="$(mkproject 'no direct net/http outside internal/httpx
  → ADR-014
  check: test -f absent-marker')"
  run "$d"
  expect_eq "violated: exit 1" 1 "$rc"
  expect_contains "violated: stderr names the rule" \
    "no direct net/http outside internal/httpx" "$err"
  expect_contains "violated: stderr names the command" \
    "test -f absent-marker" "$err"
  expect_eq "violated: stdout stays empty" "" "$out"
  rm -rf "$d"
}

t_adr_pointer_is_not_a_rule() {
  # The "→ ADR-014" line is a pointer, not a second rule. One rule in, one out.
  local d
  d="$(mkproject 'a rule with a pointer
  → ADR-014
  check: false')"
  run "$d" --count
  expect_eq "pointer: counted as one rule" "1/1 rot" "$out"
  rm -rf "$d"
}

t_broken_check() {
  # A check whose command does not exist is broken tooling, not a violated
  # decision. Exit 2 keeps the Stop hook from blocking over a typo.
  local d
  d="$(mkproject 'a rule with a typo in its check
  check: definitely-not-a-real-binary-xyz')"
  run "$d"
  expect_eq "broken: exit 2" 2 "$rc"
  expect_contains "broken: stderr names the rule" "a rule with a typo in its check" "$err"
  if [[ "$err" == *"verletzt durch"* ]]; then
    no "broken: not reported as a violation" "stderr says 'verletzt durch': $err"
  else
    ok "broken: not reported as a violation"
  fi
  rm -rf "$d"
}

t_timeout_is_broken_not_violated() {
  local d
  d="$(mkproject 'a rule whose check hangs
  check: sleep 5')"
  ARCH_CHECK_TIMEOUT=1 run "$d"
  expect_eq "timeout: exit 2" 2 "$rc"
  expect_contains "timeout: stderr names the rule" "a rule whose check hangs" "$err"
  rm -rf "$d"
}

t_broken_outranks_violated() {
  local d
  d="$(mkproject 'rule one
  check: false

rule two
  check: definitely-not-a-real-binary-xyz')"
  run "$d"
  expect_eq "broken+violated: exit 2 wins" 2 "$rc"
  expect_contains "broken+violated: violation still reported" "rule one" "$err"
  rm -rf "$d"
}

t_runs_at_project_root() {
  # Checks are written relative to the project root, so they must run there
  # regardless of the agent's cwd.
  local d
  d="$(mkproject 'the marker file lives at the project root
  check: test -f marker')"
  touch "$d/marker"
  mkdir -p "$d/sub/deeper"
  rc=0
  (cd "$d/sub/deeper" && CLAUDE_PROJECT_DIR="$d" "$ARCH_CHECK") >/dev/null 2>&1 || rc=$?
  expect_eq "root: check passes from a subdirectory" 0 "$rc"
  rm -rf "$d"
}

t_json() {
  local d
  d="$(mkproject '# Constraints

rule alpha
  → ADR-001
  check: false

rule beta
  check: true')"
  run "$d" --json
  expect_eq "json: exit 0 (data mode)" 0 "$rc"
  if printf '%s' "$out" | jq -e . >/dev/null 2>&1; then
    ok "json: valid JSON"
  else
    no "json: valid JSON" "$out"
  fi
  expect_eq "json: checked count" 2 "$(printf '%s' "$out" | jq -r '.checked')"
  expect_eq "json: violated count" 1 "$(printf '%s' "$out" | jq -r '.violated')"
  expect_eq "json: broken count" 0 "$(printf '%s' "$out" | jq -r '.broken')"
  expect_eq "json: violated rule text" "rule alpha" \
    "$(printf '%s' "$out" | jq -r '.rules[] | select(.status=="violated") | .rule')"
  expect_eq "json: markdown heading is not a rule" 2 \
    "$(printf '%s' "$out" | jq -r '.rules | length')"
  rm -rf "$d"
}

t_count_surfaces_broken() {
  # --count feeds the SessionStart hook. A broken check is not "green". If it
  # only counted violations, two typos would report as "0/2 rot".
  local d
  d="$(mkproject 'rule one
  check: false

rule two
  check: definitely-not-a-real-binary-xyz')"
  run "$d" --count
  expect_eq "count: exit 0" 0 "$rc"
  expect_contains "count: reports the violation" "1/2 rot" "$out"
  expect_contains "count: reports the broken check" "kaputt" "$out"
  rm -rf "$d"
}

t_count_stays_quiet_when_nothing_broken() {
  local d
  d="$(mkproject 'rule one
  check: false')"
  run "$d" --count
  expect_eq "count: no broken suffix when none broken" "1/1 rot" "$out"
  rm -rf "$d"
}

t_only() {
  local d
  d="$(mkproject 'rule alpha
  check: false

rule beta
  check: false')"
  run "$d" --only beta
  expect_eq "only: exit 1" 1 "$rc"
  expect_contains "only: selected rule reported" "rule beta" "$err"
  if [[ "$err" == *"rule alpha"* ]]; then
    no "only: unselected rule skipped" "alpha leaked into: $err"
  else
    ok "only: unselected rule skipped"
  fi
  rm -rf "$d"
}

t_only_no_match() {
  local d
  d="$(mkproject 'rule alpha
  check: false')"
  run "$d" --only nonexistent
  expect_eq "only: no match exits 2" 2 "$rc"
  expect_contains "only: no match explains itself" "nonexistent" "$err"
  rm -rf "$d"
}

# ------------------------------------------------- checks in ADR frontmatter

# adr <projectdir> <relative path> <status> <checks yaml block or NOCHECKS>
adr() {
  local dir="$1" rel="$2" status="$3" checks="$4"
  mkdir -p "$dir/$(dirname "$rel")"
  {
    printf -- '---\n'
    printf 'id: 0003\ntitle: Exakte Arithmetik\nstatus: %s\n' "$status"
    [[ "$checks" != NOCHECKS ]] && printf '%s\n' "$checks"
    printf -- '---\n\n## Kontext\n\nProsa bleibt Prosa.\n'
  } >"$dir/$rel"
}

SATISFIED='checks:
  - desc: Koordinaten ausschliesslich ueber Exact.t
    run: "true"'

VIOLATED='checks:
  - desc: Keine Float-Literale im Geometrie-Kern
    run: "test -f absent-marker"'

t_adr_frontmatter_satisfied() {
  local d
  d="$(mkproject NOFILE)"
  adr "$d" docs/adr/0003-exact-arithmetic.md accepted "$SATISFIED"
  run "$d"
  expect_eq "adr/satisfied: exit 0" 0 "$rc"
  expect_eq "adr/satisfied: silent" "" "$err"
  rm -rf "$d"
}

t_adr_frontmatter_violated_names_desc_and_file() {
  local d
  d="$(mkproject NOFILE)"
  adr "$d" docs/adr/0003-exact-arithmetic.md accepted "$VIOLATED"
  run "$d"
  expect_eq "adr/violated: exit 1" 1 "$rc"
  expect_contains "adr/violated: names the check desc" \
    "Keine Float-Literale im Geometrie-Kern" "$err"
  expect_contains "adr/violated: names the source file" \
    "docs/adr/0003-exact-arithmetic.md" "$err"
  expect_contains "adr/violated: names the command" "test -f absent-marker" "$err"
  rm -rf "$d"
}

t_archive_and_draft_are_not_checked() {
  # The directory carries the status: only what is directly in the ADR
  # directory is current truth.
  local d
  d="$(mkproject NOFILE)"
  adr "$d" docs/adr/archive/0002-old.md accepted "$VIOLATED"
  adr "$d" docs/adr/draft/0009-idea.md proposed "$VIOLATED"
  run "$d" --count
  expect_eq "adr/archive+draft: nothing to check" "0/0 rot" "$out"
  rm -rf "$d"
}

t_adr_without_checks_is_ignored() {
  local d
  d="$(mkproject NOFILE)"
  adr "$d" docs/adr/0001-prose-only.md accepted NOCHECKS
  run "$d" --count
  expect_eq "adr/no checks: not counted" "0/0 rot" "$out"
  rm -rf "$d"
}

t_malformed_frontmatter_is_broken_not_green() {
  # Silently skipping an unparsable ADR would report it as green.
  local d
  d="$(mkproject NOFILE)"
  mkdir -p "$d/docs/adr"
  printf -- '---\nchecks: [ this is not: valid yaml\n---\n\n## Kontext\n' \
    >"$d/docs/adr/0004-broken.md"
  run "$d"
  expect_eq "adr/malformed: exit 2" 2 "$rc"
  expect_contains "adr/malformed: names the file" "0004-broken.md" "$err"
  rm -rf "$d"
}

t_both_sources_are_read() {
  local d
  d="$(mkproject 'a bare convention with no record
  check: false')"
  adr "$d" docs/adr/0003-exact-arithmetic.md accepted "$VIOLATED"
  run "$d" --count
  expect_eq "both: adr and constraints counted together" "2/2 rot" "$out"
  rm -rf "$d"
}

t_finds_other_adr_layouts() {
  local d
  d="$(mkproject NOFILE)"
  adr "$d" notes/adr/007-vanilla-hcl.md accepted "$VIOLATED"
  run "$d" --count
  expect_eq "layout: notes/adr is found" "1/1 rot" "$out"
  rm -rf "$d"
}

t_json_carries_the_source() {
  local d
  d="$(mkproject NOFILE)"
  adr "$d" docs/adr/0003-exact-arithmetic.md accepted "$VIOLATED"
  run "$d" --json
  expect_eq "json: source path" "docs/adr/0003-exact-arithmetic.md" \
    "$(printf '%s' "$out" | jq -r '.rules[0].source')"
  rm -rf "$d"
}

# ---------------------------------------------------------------- driver

for t in $(declare -F | awk '$3 ~ /^t_/ {print $3}'); do
  printf '%s\n' "$t"
  "$t"
done

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
