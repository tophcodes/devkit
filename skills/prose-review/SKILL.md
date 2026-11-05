---
name: prose-review
description: Use when prose written for other people is about to go to colleagues - a PR or issue body leaving draft, a doc, ADR, README, runbook, release note - and should be checked before they read it. Also load it before drafting any GitHub issue, PR or comment on Toph's behalf, for the writing-voice guide. Also use when a reader calls a text cryptic, vague, hand-wavy or abstract, asks what a sentence is supposed to mean, or a rewrite has to be verified as clearer than what it replaced. Runs the Vale check, then a blind paraphrase by a fresh subagent. Not required for every draft PR, not for code review of a diff, and not for "does this doc land, for whom", which audience-review does.
---

# Prose review

A sentence can pass every pattern check and still leave the reader unable to
say what happens. "Calls already dialling can still end in a result, so a
window can close above the limit" has no em dash, no antithesis and no hedge.
Its faults are a figurative verb on an abstraction, an abstraction as the
subject, and a term the writer coined during the session. A reader without
the writer's context catches those. The writer does not, and neither does a
model judging text in the context that produced it: it prefers its own
phrasing and agrees with itself.

So the review has two layers. Vale decides what a pattern can decide. A fresh
subagent that sees only the text does the rest.

## When

Run it when a text is about to reach colleagues: a PR moves out of draft, an
issue or ADR is filed, a doc is published. A draft PR that only you will read
does not need it. Suggest the review at that moment; do not run it on every
body you write.

## GitHub writing voice

This section applies whenever you draft a GitHub issue, PR or comment on
Toph's behalf, review or not.

- Before drafting any GitHub issue, PR, or comment on the user's behalf, load the writing-style guide.
- **The guide describes, it does not permit.** Its corpus mixes Christopher's
  own writing with agent-written text, so a good part of it documents how
  agents write in his name. Read it for structural cues: body length, heading
  habits, where ticket references go, English vs German, third-person voice in
  PRs. [[antithesis]] outranks it. Where the guide reports a habit that those
  rules ban (it calls em dashes "common", for one), the rules win and the
  guide's observation is evidence of contamination. Never cite the guide as a
  reason for a banned construction.
- Run the [[antithesis]] check over GitHub prose before posting it.
- Prose already in an issue or PR that Christopher did not write this session
  stays as it is. Edit only your own draft.
- **Source order**:
  1. Read local cache `~/.claude/WRITING_STYLE.md` if it exists.
  2. Otherwise fetch from canonical gist: `https://gist.githubusercontent.com/tophcodes/3c001aa2989c17fa7785f4ee6f8a2a6d/raw/WRITING_STYLE.md` (use WebFetch; URL serves latest revision).
  3. Cache the fetched content locally to `~/.claude/WRITING_STYLE.md` for next session if the file is writable.
- **To update the canonical version** after editing `~/.claude/WRITING_STYLE.md`: `gh gist edit 3c001aa2989c17fa7785f4ee6f8a2a6d ~/.claude/WRITING_STYLE.md`

## 1. Vale

```sh
prose-check --output=line <file>
printf '%s' "$text" | prose-check --output=line --ext=.md
```

`prose-check` is Vale with this repository's config. Two styles:

- **Prose**: the high-precision rules (em dash, Gedankenstrich, antithesis,
  rhetorical setups, hedging adverbs, German Floskeln). Every hit is an error.
  Fix all of them.
- **Slop**: vale-llm-slop, at warning or suggestion. Triage each hit: rewrite
  it when the flagged word carries no information, keep it when it is the
  right word here. Say which you kept and why in one line.

## 2. Blind reader

Dispatch one fresh subagent (`general-purpose`) with only the text. No file
paths, no tools it needs, no summary of what the text is meant to say, no
context from this session. The prompt asks for three things per paragraph:

1. A paraphrase in the reader's own words.
2. For every sentence: the actor and the action. "none" when no actor can be
   named.
3. Every term it cannot define from the text alone.

Tell it to report what the text says, and to write "unclear" rather than
guess. A reader that fills gaps from plausibility hides the gaps.

## 3. Compare

Hold the paraphrase against what you meant. The findings are:

- **Mismatch**: the paraphrase says something other than the intent, or
  leaves a part out.
- **No actor**: the subagent wrote "none", or named an abstraction.
- **Undefined term**: anything on its list. A term coined during the session
  shows up here.

Then run the five cuts over every sentence that says how something works.

**Who acts?** A mechanism needs an actor the reader can point at. "A scheduled
run retakes deliveries" names none: what runs it, on what trigger, how often.
"A cron job looks for X every few minutes and queues it again" does.
Nominalisations and agentless passives are where actors go missing.

**How much?** Vague magnitudes stay vague: "for long enough", "a bounded
time", "after a while". Give a number, a bound or an order of magnitude, or
name the thing that sets it.

**Circular?** "Deliveries that have been sitting unfinished for long enough
that their processing must be considered lost" defines the condition by its
own conclusion. State what is observable instead: the job never reported back.

**Literal?** A figurative verb on an abstraction hides the mechanism: a window
"closes above" a limit, a call "ends in" a result, a queue "absorbs" load.
Replace the verb with what the actor does: the counter exceeds the limit
before the period ends.

**So what?** After the sentence, can the reader do, predict or decide
something they could not before? If not, it goes.

Abstraction is right where a concrete value would rot: a constant, a schedule,
a file layout. The abstract version still has to be executable in the reader's
head. "A cron job queues them again, for a few days" drifts no more than
"recovery happens inside the window", and only one of them can be acted on.

Every domain term gets a gloss at first use or goes: aggregate, idempotent,
dunning, backpressure, saga, projection, tombstone.

## 4. Rewrite and recheck

Rewrite the flagged sentences. Rerun step 1 on the whole text, then step 2
with a new subagent on the rewritten sentences only. Stop when the paraphrase
matches the intent and every sentence has an actor.

## The report

1. The three sentences a reader stumbles on first. Quote at most twelve words
   of each, name the finding or the cut, and give the replacement.
2. The remaining findings in the same shape, grouped by cut.
3. The Slop hits you kept, one line each.

Do not open with a verdict on the surface rules. Clean grammar says nothing
about whether a reader can follow the text.

## Red flags in your own review

- You judged the text yourself instead of dispatching the blind reader.
- You gave the subagent the intent, the file path or a summary.
- You praised a paragraph you could not paraphrase without rereading it.
- Your findings cluster in one paragraph while another got no attention. The
  fog is usually thickest where you skimmed.
