# Module: decision

A choice with nothing to build: a tool, a vendor, a purchase, an approach, or
whether to do the thing at all.

## Criteria before options

Establish what would make an option good **before** naming any option.
Reversed, the criteria get written to fit the option that was already
favoured, and the comparison becomes theatre.

Ask, one at a time:

- What has to be true for this to count as solved?
- What is the constraint that binds: money, time, maintenance,
  reversibility, who else has to live with it?
- Which criteria are hard requirements and which are preferences? Say which.
- How long does this decision have to hold, and what would make it wrong later?

## Then the options

Two to four, each with its real cost, not a token drawback. Always include the
option of doing nothing. Often it wins, and when it loses it is still the
baseline everything else is measured against.

State a recommendation. A list of options with no recommendation hands the work
back.

Be honest where the evidence is thin. "I don't know how well X handles Y" is
more useful than a confident guess, because it names something worth checking
before committing.

## Output by level

**Level 0**: no file. Some choices are made in one exchange and do not need to
survive the conversation.

**Level 1**: the default. A note containing:

- The decision, in one sentence.
- The criteria, marked hard or soft.
- The options considered, each with its cost.
- What was rejected and why. This is the part that stops the same question
  coming back in four months.
- A revisit trigger: the concrete thing that would make this worth reopening.

Where it goes: if a repository is involved, its decision store (`notes/adr/`,
`docs/decisions/`, whatever `arch-harness:arch-context` finds). If none is,
**ask once** where it should live. Do not invent a path.

**Level 2 and 3 do not apply.** A decision that needs a spec or a plan is not
a decision any more: the choice is made and the work is now `code` or `infra`.
Re-triage into that module rather than stretching this one.
