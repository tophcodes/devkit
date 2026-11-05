# Module: infra

The fleet: NixOS hosts, Nomad jobs, networking, DNS, secrets,
backups, monitoring. Repository: `~/infra`.

## First, find out what already binds

Run `arch-harness:arch-context` before anything else. It surfaces the active
constraint checks and the decision records that already cover the area. This is
the cheapest step in the whole module and it prevents the failure mode this
repository is most prone to: deciding a second time, differently, something
that was settled months ago.

Decision records live in `notes/adr/`; `notes/adr/000-adr-process.md` defines
the format. Constraint checks live in `docs/constraints.md` and in the
`checks:` frontmatter of the records.

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

**Level 1**: an ADR in `notes/adr/`, following the process document. Not a
spec: the artefact is the decision and its reasoning, not a build description.

**Level 2**: a design document in `docs/`, alongside an ADR if a real
architectural choice was made. Run `arch-harness:arch-review` against it before
executing.

**Level 3**: as above, plus a plan written in plan mode and saved under
`docs/plans/`. Warranted here more
often than in other domains: migrations of live state, multi-host rollouts, and
anything where the order of operations is what keeps the service up.

## Follow-on skills

- `arch-harness:arch-context`: always, first.
- `arch-harness:arch-review`: level 2 and up, before executing.
- `encrypt-secret`: when the design introduces a new secret.
