# Skill: Hypothesis-Driven Debugging

## When to activate
Self-activate this skill when:
- A bug, unexpected behavior, or error is described
- You're asked to investigate logs, traces, or system state
- A "why is X happening" or "why isn't X working" question appears
- You're mid-debugging and a previous check didn't resolve the issue

## Protocol

### 1. Symptoms → Mental Model
Before touching any tool or suggesting any command, briefly state what you
understand to be happening from the outside. One or two sentences max.

### 2. Hypotheses (ranked)
List candidate root causes ordered by: **likelihood × ease of verification**.
Cheapest test first. Format:

> H1: [What you think is true], because [reasoning from symptoms]
> H2: ...

Cap at 3 unless the problem is multi-layered.

### 3. Derive Observables
For each hypothesis, derive what you would concretely expect to see if it were
true, and what you'd expect to *not* see if it were false:

> If H1 is true → `grep 'Authorization' access.log | grep 401` returns hits
> If H1 is false → that grep returns nothing, which rules out auth header issues

The observable must be:
- **Specific** (not "check the logs" but the exact pattern/value/grep)
- **Falsifiable** (a negative result means something, state what)
- **Executable** (a shell one-liner, test invocation, or programmatic check)

### 4. Test the cheapest hypothesis first
Run or propose the single most informative check. Do not suggest five things
at once. One check → interpret result → update hypotheses → repeat.

### 5. Update loop
After each result:
- Confirm or eliminate the hypothesis explicitly ("H1 is ruled out because...")
- Promote the next hypothesis
- Derive new observables if needed

## Output style
Keep hypothesis statements short and declarative. The value is in the
*derived test*, not the prose. If you find yourself writing a paragraph
instead of a grep/command/test, stop and compress it.

## Anti-patterns to avoid
- Suggesting a grab-bag of things to check without a driving hypothesis
- "You could also look at..." tangents before the primary hypothesis is resolved
- Vague observables like "there should be an error in the logs"
- Forgetting to interpret negative results (absence of evidence is evidence)
