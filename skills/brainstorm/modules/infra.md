# Module: infra

The fleet: NixOS hosts, Nomad jobs, networking, DNS, secrets,
backups, monitoring. Repository: `~/infra`.

## First, find out what already binds

Read the specification that already covers the area before anything else:
`openspec list --specs` lists the capabilities, `openspec show <capability> --type spec`
reads one, and `openspec list` shows the open changes. Architecture decisions are
requirements there. This is the cheapest step in the whole module and it prevents
the failure mode this repository is most prone to: deciding a second time,
differently, something that was settled months ago.

The requirements a shell command can check have an entry in `docs/constraints.md`;
`just check` runs them. `notes/legacy/` holds the archived ADRs the specification
was distilled from, as background only.

## Ask about

- Which hosts does this touch, and does any of them carry state?
- Is it reversible? A rebuild rolls back; a migrated database does not.
- What does it depend on that is not in this repository: an external service,
  a device, a registrar?
- Does it need a secret, a host volume, a DNS name, a certificate?
- What breaks while it is being changed, and who notices?

## Repository rules that shape every design here

- **Everything declarative.** A manual step is not a solution. If a design
  needs one, that is a finding, not a footnote.
- Activation through `just switch` / `just deploy <host>`, never raw
  `nixos-rebuild`.
- New files must be `git add`ed; flakes only see tracked files.
- **Never take versions, image tags or config schemas from memory.** Check the
  upstream source before writing one down.
- New Nomad jobs are HCL (`job.hcl`), never the legacy Nix DSL. Bridge
  networking with `address_mode = "alloc"`.

## Output by level

**Level 0**: no file.

**Level 1**: an OpenSpec change that records the decision: the requirement it adds
or changes, and a `design.md` with the reasoning and each rejected alternative.
No task list beyond what archiving needs.

**Level 2 and 3**: an OpenSpec change through `openspec-propose`: proposal, spec
deltas, design and tasks. Its `tasks.md` carries the order of operations, which
matters here more often than in other domains: migrations of live state,
multi-host rollouts, and anything where the order is what keeps the service up.

## Follow-on skills

- `openspec-explore`: while the shape is still open.
- `openspec-propose`: level 1 and up, once the design is agreed.
- `encrypt-secret`: when the design introduces a new secret.
