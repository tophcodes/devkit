# Comments & Documentation

## Code comments & doc comments

Doc comments describe the contract in the present tense: what the thing does, what it takes, what it returns, what it rejects. Never how it came to be.

**Does not belong in source (it's process noise, not a decision):**
- Refactor provenance: "lifted out of X", "moved from Y", "used to be Z", "this supersedes the old W", "the old kernel this replaced was deleted in …"
- Process artefacts: "Task 6", "Plan 3c Task 2", "this slice", plan filenames, session names
- Commit SHAs as justification

**Does belong, because it is a present fact the reader needs:**
- Why a non-obvious choice is load-bearing ("must stay one `let rec` chain; splitting it breaks the fixpoint")
- A pointer to a *durable* document: ADR 0017, issue #48; not a spec (see below)
- A known limitation that still applies

**The test:** would the sentence be false or meaningless to someone who never saw the change that introduced it? Then it's not code, it's a decision, and it needs an owner:
- Load-bearing and short → a comment at the code, per the list above.
- Not short, or relevant beyond this one spot → extract it into a long-lived document (ADR, issue, design doc) and leave a short pointer at the code so an agent working here later finds it.

Don't default to "the commit message will hold it": nobody reads commit body text later, so it isn't a findable fallback for anyone.

Rationale that is currently phrased as history usually needs rewording, not deletion: "both now live in the caller because they need X" becomes "these live in the caller because they need X".

This is the "journal comment" / "changelog comment" antipattern: re-implementing source control inside the source, where it rots on the next edit.

## Documentation & ADRs

Before writing a doc/ADR line, ask: does it reference an implementation detail (a file, a function, a config value, a current codebase shape) that could silently drift when someone changes that thing elsewhere and never comes back to update this doc? If yes, don't reference it directly. Reference the stable decision or contract behind it instead, or drop the line.

**The test:** would this sentence start lying the next time someone touches the code it describes, without them ever knowing this doc exists to update? Then it's not durable. Only write down things meant to outlive the implementation: decisions, constraints, trade-offs made and why. Not current file layouts, current function names, or anything from a temporary/working doc.
