# Design

## Context

ADR-001 (2026-10-21) set up devkit. This document keeps its reasoning, because
the ADR is deleted once the change is archived and the specifications state
only the outcome.

Before devkit, Toph's own repositories (about 90 under `~/code`) shared no way
to be built, tested or started. 45 had a flake, 10 used devenv, some used both.
just ran in four repositories, make in three, go-task and mise in one each.
Four problems followed:

- After a few weeks away, Toph had to rediscover how a repository is built,
  tested and started.
- Agents guessed commands, because no repository offered a known entry point.
- Each repository's development environment worked differently.
- Helper programs of a project had no fixed place and no fixed invocation.

ADR-001 held four hard criteria:

- **Same vocabulary.** Every repository answers to the same recipe names.
- **Tools without a checkout.** A project tool runs via `nix run <flake>#<tool>`
  from any directory.
- **CI equals local.** The command that checks a repository locally is the
  command CI runs.
- **Fast loop.** Running the tests does not evaluate the flake on every run.

## Goals / Non-Goals

**Goals:**

- Every decision ADR-001 made that still holds is a requirement in
  `openspec/specs/`.
- The reasons and the rejected alternatives stay readable in the change
  archive.

**Non-Goals:**

- No behaviour of the module, the templates or the packages changes.
- The arch-check and arch-harness packages, which read ADR directories in
  other repositories, stay as they are.

## Decisions

**Four capabilities.** The ADR's decisions fall into four groups that change
for different reasons: the recipe contract (`command-surface`), the linters
(`quality-gates`), the templates (`templates`), and the constraints a
repository takes on with devkit (`architecture`). Per infra ADR-041, layout
constraints go into `architecture`, and each of its requirements names the
change that introduced it.

**Process statements stay out of the specifications.** ADR-001 also said that
adoption happens when work next touches a repository, that no CI runs yet, and
that agents learn the convention from a user-scope rule, the devkit skill and
each template's `AGENTS.md`. None of these is behaviour devkit provides. The
template's `AGENTS.md` is covered by the `templates` capability; the rest is
kept here.

**The ADR is deleted.** ADR-041 lets each repository decide between archiving
and deleting its ADRs. This document carries everything in the ADR that the
specifications do not, so a second copy under `notes/adr/archive/` would add a
second place to keep in sync.

### Alternatives ADR-001 rejected

- **make.** A build system with timestamp-based file dependencies, while Nix
  and the language toolchains already build. As a command runner it needs
  `.PHONY`, tab indentation and `$$` escaping, has no recipe listing, and
  passes arguments only as variables.
- **go-task.** Its caching by source checksums duplicates Nix. What remains is
  shell code embedded in YAML.
- **mise tasks.** mise also manages tool versions, a second mechanism next to
  Nix.
- **Flake apps only.** Every `nix run .#test` evaluates the flake, and
  `nix flake show` lists recipes poorly. Flake apps remain the mechanism for
  tools that run without a checkout.
- **devenv everywhere.** devenv adds a tool layer, a second lock file and
  slower evaluation to repositories that need only a compiler and a linter.
- **Templates without a shared module.** A copied template drifts from its
  source, and every later improvement has to be carried into each repository
  by hand.
- **An interactive scaffolder.** Bake (`~/code/templates`) asked through
  terminal prompts which files a new project needs. An agent asks the same in
  conversation. Bake stays paused.
- **Hosting the convention in the infra repository.** Every project would pull
  the whole fleet flake into its lock file.

### Revisit when

- Tasks need cached, incremental execution that Nix makes too slow, for
  example code generation on every test run. go-task is the next candidate.
- A team repository wants this standard. The module would then have to work
  for colleagues without Nix.

## Risks / Trade-offs

- [A requirement misstates what the ADR or the module does] → each scenario
  was checked against the module's code and the Python template; `openspec
  validate --strict` checks the format.
