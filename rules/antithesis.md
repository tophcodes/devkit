# Writing for other readers

<!-- vale off -->
<!-- This file quotes the banned forms in order to name them. -->

Applies to prose written for other people: docs, ADRs, READMEs, PR and issue
bodies, commit bodies, code comments. Chat replies are exempt.

## The contract

Every sentence that says how something works:

- **Subject = who acts. Verb = what they do.** Name an actor the reader can
  point at: a cron job, the API, the user. Use the literal verb: a counter
  exceeds a limit, a window does not "close above" one.
- **Quantities as numbers or bounds.** "every five minutes", "at most three
  retries", "under a second". "Long enough" and "a while" are no quantity.
- **Only terms the reader has seen.** A term gets a gloss at first use or
  goes. A name coined while working on the change is the writer's term, and
  the reader has never seen it.
- **State what a thing is.** Defining it by what it is not (antithesis) reads
  as depth and carries less information than the direct claim.

## Named habits

These mark text as machine-written. Their full pattern lists live in the Vale
styles run by `prose-check` (Prose for the blocking rules, Slop for the rest).
This file keeps the ones a pattern cannot decide.

- **Antithesis**: "not X, but Y", "isn't A. It's B.", a trailing ", not Y.",
  noun-vs-noun reframes ("a decision, not a bug"). Rewrite as a direct claim;
  if nothing is left, delete the sentence. Budget: one real contrast per
  section, only where the reader would otherwise hold a competing reading.
- **Rhetorical setups**: "that is the point", "which is what makes it Z".
- **Em dash**, and in German the Gedankenstrich (–): finish the sentence.
- **Hedging adverbs**: really, genuinely, simply, actually; wirklich,
  tatsächlich, letztlich. Replace the verb they prop up.
- **German**: "nicht nur X, sondern auch Y", "Und genau deshalb …",
  Floskeln ("Es ist wichtig zu beachten"), Buzzwords ("nahtlos").
- **Synonym cycling**: pick a term once and keep it, even when it repeats.
- **Rule of Three**: two real items get written as two.

## The check

```sh
prose-check <file>                        # Vale: errors block, rest is triage
printf '%s' "$text" | prose-check --ext=.md
```

The prose-guard hooks run it on every written file and refuse an outbound
message (PR, issue, commit) with an error-level hit. Before a text goes to
colleagues, the `prose-review` skill adds a blind-reader pass for the faults
no pattern catches.

Related: [[comments]] on what belongs in a doc at all.
