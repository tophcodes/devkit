---
name: audience-review
description: Review prose by simulating several independent readers with different backgrounds, then verifying what they claimed. Works on one artifact (README, ADR, spec, PR description, announcement, docs page) or on a whole set of pages when the question is how they are arranged. Use when the user asks whether a document lands, who it currently serves, whether a newcomer could follow it, whether its claims are believable, whether a docs site is structured for the people it wants, or says things like "audience review", "read this as X", "does this doc work", "should we restructure the docs". Not for code review of a diff.
---

# Audience review

A document is only readable relative to a reader. One reviewer with full
context cannot tell you that your README serves exactly one audience: they
*are* that audience. Several independent readers can, because the thing you
learn is not any single reaction but the **overlap**: the point where four
different people fall out of the text for the same reason.

Two verdicts per reader, and both matter:

- **Comprehension**: do I understand what this is, and can I act on it?
- **Credibility**: do I believe it? A decision presented as forced by an
  inevitability, with no cost named, reads as marketing to anyone who knows
  the domain. That is usually the sharpest finding in the run and it is never
  a comprehension problem.

## Step 0: One artifact, or a set

Two questions need two shapes, and mixing them wastes the run.

**One artifact** is the default: does *this document* land, for whom, and is
it believed. Readers get that text and nothing else.

**A corpus** is for when the arrangement is the question: which page should
exist, what belongs where, whether a reader with a task finds the answer at
all. Readers get every page of the set and a task to carry through it. Use
it when the user asks about restructuring, about several audiences at once,
or when a previous single-artifact run turned up findings that were
about the neighbouring pages.

Never run a corpus to judge one page's prose: with ten pages in front of
them, readers report on navigation and stop reading sentences.

The steps below apply to both. Where a corpus differs, it says so.

## Step 1: Scope the target

Establish, before anything else:

- Which artifact, or which set of pages and where a reader enters it.
- What it describes, and where that thing lives (repo path, URL), needed for
  step 5, **not** given to the readers.
- Who the author thinks it is for. Ask if unstated. The gap between intended
  and actual audience is a finding.

Read the document yourself now. You need its full text verbatim for step 3.

## Step 2: Derive the reader profiles

Propose **4–6** profiles, derived from this artifact, and get the user's
approval before dispatching. No fixed cast: a README for a protocol server
and an internal ADR have almost no readers in common.

Each profile gets:

- **Background**: what they already know, in concrete terms ("runs two Solid
  servers, has ported one", not "technical user").
- **Why they opened this document**: the question they arrived with.
- **What they would do next** if convinced. This is what "can I act on it"
  gets measured against.
- **What they do not know.** Be explicit; this is what makes the persona hold.

In a corpus run each profile also gets a **task**: the one thing they came to
do, phrased as they would phrase it ("get my own notes to render", "decide
whether to adopt this before Friday"). The task is what makes navigation
observable, since a reader without one reads page one and stops.

Spread them deliberately along:

- **Distance to the domain**: at least one reader who does not have it. If
  every profile knows the jargon, the run cannot detect jargon.
- **Stake**: someone who has to operate, maintain or trust the thing with
  their own data reads differently from someone evaluating it.
- **Adjacency**: someone who knows a *competing* or neighbouring system.
  They supply the credibility lens: they can price the claims.

Present them as a short list. The user edits, swaps, adds. Then dispatch.

## Step 3: Blind read

One subagent per profile, dispatched **in parallel, in a single message**.

Blindness is the whole design and it is fragile:

- **Paste the document's full text into the prompt.** Never give a path, a
  repo, a URL, or the project name if the document does not state it.
- **In a corpus run, paste every page**, each under the title and path a
  reader would see in the navigation, in the order the navigation shows
  them. Strip only what a reader never sees: frontmatter, and the page
  format's own component imports. Never strip inside a code fence. A regex
  over `^import` eats the examples' import lines along with the page's, and
  the readers then report a gap that is yours. Say that they may read in any order and must report the order they
  took. Rendered elements a reader would see but the source does not carry
  (a live example, an embedded diagram) get a bracketed one-line
  description in place.
- **Forbid tools.** No file reads, no grep, no web search, no shell. A reader
  who can look up the answer stops being able to notice that the document
  never gave it.
- If they want to check something, they record it as an open question and
  carry on. Those questions are the input to step 5.
- No persona ever sees another persona's output, or knows others exist.

Give every persona the **same question set**, so the answers can be compared:

1. In one sentence, in your own words: what is this thing? If you cannot, say
   so and quote the furthest line you got.
2. Is it for you? On what evidence in the text.
3. First point where you stopped being able to follow or act? **Quote it**.
4. What would you do next, and does the document let you? Walk the steps.
5. Which claims do you not believe, and what would change that.
6. Where does the text argue rather than state: a decision presented as
   inevitable, a cost not named, a word doing rhetorical work it has not
   earned? Quote it.
7. What is missing that you need before you would use or trust this.
8. Verdict: do you proceed? If not, the one thing that would flip it.

A corpus run adds five, and they are the point of it:

9. Which pages did you open, in which order, and where did you give up.
10. Which page did you expect to hold your answer, and which one held it.
11. What did you read that you did not need, and at what point.
12. What page is missing, and what would you call it.
13. What would you merge, split, drop or rename.

Tell them plainly: their honest reaction is the deliverable, including "I gave
up in paragraph two". A polite reader is a useless one.

## Step 4: Cross-compare

Do this yourself, not in an agent.

- Group findings that are **the same finding**, and count how many personas
  reached it **independently** (n/N).
- In a corpus run, group the **wrong turns** the same way: several readers
  looking for one answer on the same page that does not carry it is a
  structural finding, and it outranks any complaint about the page they
  landed on. Do not merge two findings that merely
  sit near each other to inflate a count. n/N reported honestly is the signal;
  an inflated one destroys the method.
- Look for the **single common failure point**. Often four readers fall out at
  one line for one reason. That sentence is the report's headline.
- Note which profile the document currently *does* serve. There is usually
  exactly one, and naming it is more useful than any individual complaint.
- Keep comprehension and credibility findings apart. They get fixed by
  different edits.

## Step 5: Verify

Now, and only now, take the repo/URL from step 1 and check what the readers
asserted. This pass has full tool access.

Three things to resolve:

- **Quotes**: does each quoted line exist in the document, as
  quoted. A misquoted finding is dropped. In a corpus run a quote carries
  the page it came from, and the page is part of what gets checked.
- **Factual claims** about the subject ("it says X works, does X work?", the
  open questions from step 3): mark each **confirmed / refuted /
  unresolvable**. Unverified claims stay in the report labelled as such, they
  do not get promoted.
- **Doc problem vs. real gap.** A reader saying "I cannot install this" may
  have found a missing paragraph, or a build that fails. These are
  different bugs with different owners, and the second kind is why the run is
  worth doing. Report them in their own section, never mixed into the
  documentation findings.

Delegate this to subagents when the surface is large; keep the findings, not
the file dumps.

## Step 6: Report

Terminal output only. Write no file unless asked.

1. **Headline**: who the document serves today, and the one point where the
   others fall out. For a corpus: which reader the arrangement serves, and
   the one turn the others got wrong.
2. **Comprehension findings**: table: finding, n/N independent, quoted line,
   verification status. Ordered by n/N.
3. **Credibility findings**: claims not believed, and rhetoric that costs
   trust. Quote, then what the honest version would say.
4. **Not a documentation problem**: real gaps in the subject, with the
   evidence from step 5.
5. **Unresolved**: what could not be verified, so the user knows the edges.
6. **Proposed structure**, corpus runs only, and only for reshuffles that
   two or more readers named independently. One table: page, what it is for,
   which reader it serves, what changes. Anything proposed by a single
   reader goes in the findings as that reader's opinion.

Stop there. No rewrite, no patch, no applied fix. The user decides what to
change. Offer once, at the end, and only if they ask.

## Rules

- Independence is the product. Never run several personas inside one agent,
  never let them see each other, never summarise persona A into persona B's
  prompt.
- Every comprehension finding carries a quote from the document. Without one
  it is an impression.
- Do not defend the document. If a persona misread it, that is data about the
  document, not about the persona, unless step 5 shows the quote was invented.
- One artifact per run, or one corpus when the arrangement is the question.
  Two unrelated documents still means two runs.
