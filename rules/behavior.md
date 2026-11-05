# Behavioral Guidelines

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

### Resolution ladder

Before writing code, stop at the first rung that holds:

1. **Does this need to exist?** Speculative need gets skipped, in one line (YAGNI).
2. **Already in this codebase?** A helper, type or pattern that lives here gets reused. Grep before you write. Re-implementing what sits three files over is the most common slop.
3. **Stdlib covers it?** Use it.
4. **Native platform feature covers it?** `<input type="date">` over a picker library, CSS over JS, a DB constraint over app code.
5. **Already-installed dependency covers it?** Use it. A new dependency for what a few lines do is a no.
6. **One line?** One line.
7. Otherwise: the minimum that works.

Two guards keep the ladder from turning into damage:

- It runs after you understand the problem. Read the code the change touches and trace the real flow first, then climb. A small diff in the wrong place is a second bug.
- Trust-boundary validation, data-loss handling, security and accessibility never get cut. The code ends up small because that is what the task needs, never because it was golfed.

A deliberate shortcut with a known ceiling (global lock, O(n²) scan, naive
heuristic) gets a comment naming the ceiling and the upgrade path, per
[[comments]] on known limitations.

Adapted from [ponytail](https://github.com/DietrichGebert/ponytail).

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

Write the test before the implementation. A test that already passes before the
change proves nothing about the change.

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.
