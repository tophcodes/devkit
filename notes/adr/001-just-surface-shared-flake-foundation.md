---
id: 001
title: just as the command surface, a shared flake as the foundation
date: 2026-10-21
status: accepted
---

# ADR-001: just as the command surface, a shared flake as the foundation

## Context

Toph's own repositories, about 90 under `~/code`, share no common way to be
built, tested or started. 45 have a flake, 10 use devenv, some use both. just
runs in four repositories, make in three, go-task and mise in one each; most
have no task runner at all. Four problems follow from this:

- After a few weeks away, Toph has to rediscover how a repository is built,
  tested and started.
- Agents guess commands, because no repository offers a known entry point.
- Each repository's development environment works differently.
- Helper programs of a project, such as a label generator or an importer, have
  no fixed place and no fixed invocation.

## Criteria

All four are hard requirements.

- **Same vocabulary.** Every repository answers to the same recipe names,
  whatever toolchain runs underneath.
- **Tools without a checkout.** A project tool runs via
  `nix run <flake>#<tool>` from any directory.
- **CI equals local.** The command that checks a repository locally is the
  command CI runs.
- **Fast loop.** Running the tests does not evaluate the flake on every run.

## Decision

**devkit provides the foundation.** The devkit repository exports a
flake-parts module and one template per language. The module carries what every
repository shares and should evolve in one place: the base development shell,
the formatter, and the wiring of `checks`. Repositories import it as a flake
input and pick up changes with `nix flake update devkit`.

A template is a thin skeleton: a flake that imports the module, an `.envrc`
with `use flake`, and a justfile. devkit's own `nix flake check` instantiates
and builds every template, so each template is a known-working starting point
that an agent extends.

**The module gates text as well as code.** Agents write most of the code and
prose in these repositories, so every repository gets the same linters without
asking for them: deadnix and statix for Nix, shellcheck for shell scripts,
typos for spelling, and prose-check for prose in documents and code comments.
`nix flake check` fails on their errors, and with it CI. devkit owns
prose-check; the infra repository consumes it from devkit for its writing
hooks.

**devenv joins through its flake-parts module** in repositories that need
services such as a database, a queue or long-running processes. Such a
repository still has one flake and one lock file.

**just is the single command surface.** Every repository has a justfile with
these recipes:

| Recipe    | Does                                                    |
|-----------|---------------------------------------------------------|
| `default` | lists all recipes                                       |
| `dev`     | starts the development loop: server, watcher or REPL    |
| `test`    | runs the tests and passes its arguments to the runner   |
| `fmt`     | formats all files                                       |
| `check`   | runs `nix flake check`, which is everything CI checks   |

`build`, `run`, `deploy` and `clean` exist where the repository has such a
step. Project-specific recipes sit beside them.

`test` runs inside the direnv shell and evaluates no flake. `check` and CI
both call `nix flake check`, whose checks run the same test command that
`test` runs.

The justfile is a plain file in each repository, so a reader sees what
`just test` does in that repository. The devkit module may add a check that
fails when one of the required recipes is missing.

**Each directory has one role.**

- `packages/<name>/` holds parts of the product: libraries and applications
  that ship or that other code consumes, as members of the language's
  workspace. Rust workspaces use `crates/` by convention.
- `tools/<name>/` holds standalone programs that serve the project and do not
  ship with it. A tool has its own dependencies and tests, the flake exports
  it as `packages.<name>` and `apps.<name>`, and the justfile has a recipe of
  the same name. A tool that needs the project's core library becomes a
  subcommand of the main program instead.
- `scripts/` holds single-file glue without dependencies or tests of its own,
  called from recipes. A script that gains dependencies or tests moves to
  `tools/`.

**CI on Forgejo calls `nix flake check`** through a reusable action in the
ci-actions repository.

**Foreign repositories keep their own tooling.** This covers team repositories
such as HAUSGOLD's. An overlay kept outside the repository, versioned
separately and linked from an untracked `.envrc`, is available as an escape
hatch. No repository is required to have one.

**Adoption happens on touch.** New repositories start from a devkit template.
An existing repository moves to the standard the next time work happens in it.
Repositories nobody works in stay as they are.

**Agents learn the convention from a user-scope rule.** The rule tells them to
run `just` first in any repository, and to add the standard justfile as part
of the work when one of Toph's own repositories lacks it.

## Alternatives rejected

**make.** make is a build system with timestamp-based file dependencies, and
Nix and the language toolchains already build. Used as a command runner it
needs `.PHONY`, tab indentation and `$$` escaping, has no recipe listing, and
passes arguments only as variables. Being preinstalled everywhere counts for
nothing when the development shell ships just.

**go-task.** Its strength, caching by source checksums, duplicates what Nix
does. What remains is shell code embedded in YAML.

**mise tasks.** mise also manages tool versions, which would add a second
mechanism next to Nix.

**Flake apps only.** Every invocation of `nix run .#test` evaluates the flake,
and `nix flake show` lists recipes poorly. Flake apps remain the mechanism for
tools that must run without a checkout.

**devenv everywhere.** devenv adds a tool layer, a second lock file and slower
evaluation to repositories that need only a compiler and a linter.

**Templates without a shared module.** A copied template drifts from its
source, and every later improvement has to be carried into each repository by
hand.

**An interactive scaffolder.** Bake (`~/code/templates`) asked which files a
new project needs through terminal prompts. An agent asks the same in
conversation and adapts the answer. Bake stays paused and is not developed
further.

**Hosting the convention in the infra repository.** Every project would pull
the whole fleet flake into its lock file.

**Doing nothing.** The current state produces all four problems listed in the
context.

## Revisit when

- Tasks need cached, incremental execution that Nix makes too slow, for
  example code generation on every test run. go-task is the next candidate.
- A team repository wants this standard. The module would then have to work
  for colleagues without Nix.
