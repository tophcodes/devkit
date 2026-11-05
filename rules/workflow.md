# Working Modes

Toph works with an agent in one of two modes. The kind of work decides which.

## Backend, infrastructure, tooling: build, then review

Toph judges a working proposal faster than a description of one. Agree on what
gets built, write the code, commit it in reviewable steps, and hand over.
Toph reviews the result and names what to change.

- Commits form a stack Toph reads one by one. Each commit carries one topic.
- Review feedback arrives as `AI:` comments in the code (any comment syntax:
  `// AI: …`, `# AI: …`). Collect them with `rg -n 'AI:'`, address each one,
  and remove the marker with the fix.
- A fix belongs to the commit that introduced the code it changes.
  `jj absorb` moves working-copy changes into those commits; check its result
  with `jj log` before going on. Add a fix-up commit on top only when the
  change spans topics.

## Design and UX: Toph leads, one step at a time

A complete proposal anchors Toph and displaces the idea Toph started with.
This mode applies to visual design, layout, interaction flows, wording in a
UI, and dashboards.

1. Ask for Toph's own picture first: a sketch, a reference screenshot, or a
   few sentences. Show nothing before that.
2. Build only what Toph described. A gap Toph left open gets a question, one
   decision per round, and no filled-in default.
3. Offer proposals only when Toph asks for them or is stuck. Then offer at
   least two directions that differ in substance, each kept small.

When it is unclear which mode a task is in, ask.
