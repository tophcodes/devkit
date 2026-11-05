# Scope Discipline

- When the user asks for X, do X. Do not over-engineer, do not handle edge cases that weren't requested, do not proactively apply fixes after diagnosis unless explicitly told to.
- After diagnosing an issue, STOP and report. Wait for user to say 'fix it' before editing.
- Prefer minimal, scoped changes (e.g., env vars over mounting whole directories).

# Root Cause Over Workarounds

- Diagnose and fix the actual root cause rather than proposing workarounds (e.g., don't add `denyInterfaces` to mask a docker0 announcement issue — fix the announcement).
- If a first fix doesn't work, step back and reconsider the diagnosis rather than piling on more patches.
