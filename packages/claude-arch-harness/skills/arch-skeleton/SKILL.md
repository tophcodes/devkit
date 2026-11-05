---
name: arch-skeleton
description: Use after a spec is agreed and before writing an implementation plan, to fix how the thing will be used and get that signed off. Signatures with empty bodies where the language has them, an invocation-and-output transcript for a command line, pseudocode where nothing else fits. Also use when a plan would otherwise decide module boundaries implicitly, or when the user asks to pin down interfaces before implementation.
---

# Interface first, bodies never

The gap this closes: interface structure gets decided **while writing the
plan**, implicitly, spread across the file paths and signatures of forty
tasks. That is why the plan reads as method bodies and why reviewing it does
not work: the plan is the wrong artifact for that question.

So decide the interfaces *before* the plan, in an artifact that shows them
plainly enough to be judged in one reading and, where the language offers it,
one the compiler checks.

## Do this

1. **Derive the boundaries from the spec**, not from the eventual file layout.
   What are the units, and what does each expose to the others?

2. **Choose the form the interface has.** For a library it is
   signatures. For a command line it is the invocation and what comes back:
   a signature cannot express output text, so write the transcript. For a file
   or wire format it is a worked example of the format. Where nothing else
   fits, pseudocode. Prefer a form the compiler or type checker can check, but
   do not force a shape that hides the interface rather than showing it.

   **Write the interface only, no logic**, in the project's language:

   | Language | Form | Body |
   |---|---|---|
   | OCaml | `.mli` files | none: the language has the feature for exactly this |
   | Rust | `pub` items and traits in `lib.rs` / `mod.rs` | `todo!()` |
   | Go | interface declarations, exported signatures | `panic("unimplemented")` |
   | Python | `Protocol` / ABC, optionally `.pyi` | `...` |
   | Ruby | explicit list of public methods; RBS or Sorbet sigs if present | `raise NotImplementedError` |

3. **Run the compiler or type checker.** In four of five languages it will
   tell you whether the pieces fit. Ruby is the weak case: there the skeleton
   is a review artifact only, so keep the public-method list explicit.

4. **Read it.** A good skeleton is five minutes of reading and 100%
   architecture. If it takes longer, the design is too big for one step;
   split it.

5. **Optionally, harvest checks.** The boundaries are explicit right now,
   which is the cheapest moment they will ever be, so anything that must stay
   true ("only `internal/httpx` imports `net/http`", "every `lib/*.ml` has an
   `.mli`") is worth writing down as an executable check.

   This step is optional and stays optional. Put a check wherever the repo
   already keeps them, and if it keeps none, either start one file or skip the
   step. A repository with no ADRs, no constraints file and no check runner is
   the normal case, not a gap to be filled before the real work continues.
   Never block on this, and never introduce the machinery uninvited.

## Get it signed off: this is the gate

**Show the interface and wait for a verdict before writing any plan.** This is
the artifact your human partner reviews, and it replaces reviewing the plan
rather than adding a review to it. They say it fits, or they say what to
change. Do not treat it as something to mention in passing and move past.

It earns that place by being the only thing that is expensive to get wrong. A
plan is disposable: regenerate it, rewrite it, throw it away when the approach
turns out different. An interface that shipped wrong is what everything else
was built against.

Skip or shorten this only when your partner explicitly asks for that. "It is a
small change" is your judgement, not theirs, and it is not a reason.

## Then hand off to the plan

Tell the plan writer explicitly:

> The interface is given. Tasks fill in bodies only. No new public functions,
> no new modules, no new commands.

With the interface signed off, the plan carries no decision anyone still has to
approve. Auto-approving it, or skipping it entirely and implementing straight
from the interface, is a reasonable choice rather than a lapse.

## Do not

- Do not write any logic. A body that does something is a decision that
  escaped review.
- Do not build the whole scaffold. Take the narrowest end-to-end slice through
  the layers the feature needs, hardest problem first. That slice
  becomes the template for every parallel one, including its mistakes, so it
  is worth getting right by hand.
- Do not invent flexibility the spec did not ask for. No options structs, no
  generic parameters "for later".
