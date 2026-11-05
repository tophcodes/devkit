---
name: signature-diff
description: Use when the user asks for a signature diff, API surface, Signaturdiff, contract changes, or "what changed for callers" on a commit, branch or PR — and whenever a change is being handed over for review and only its interface matters.
---

# Signature diff

Reduce a diff to the contract it changes. Everything a caller cannot observe
is dropped: implementation, refactors, comments, tests, formatting.

Group by layer, outermost first. A reader walks from "what a client sends" to
"what the database holds" and stops as soon as the layers stop concerning them.

## Layers

Fixed order. Omit a layer with no changes; never reorder them.

| Layer | What belongs in it |
|---|---|
| HTTP API | route params (required/optional/type), response fields, status codes, error keys |
| Events | message schema fields (Avro, JSON schema, protobuf) |
| Jobs | job signatures and their argument types |
| Models | public methods, enums, validations, scopes |
| Database | tables, columns, indexes, constraints |
| Internal | helpers and private methods whose signature moved |

Layer names are the language of the codebase at hand — a frontend has
components and props where a Rails service has models and jobs. Keep the
outermost-first rule and rename the rows.

## Form

One line per changed element, `-` for gone, `+` for new, full signature. No
sentence per item.

```
POST /v1/subscriptions
- requires :plan_id, type: String          ← weg
  requires :owner_gid                        bleibt
```

Unchanged neighbours appear only where their absence would read as removal.
A short line after a block carries what the signatures cannot say — a queue
that must drain before deploy, a field consumers still read.

## Breaking risk (only on request)

A second pass, never mixed into the layers: name each downstream consumer and
what it has to change. Produce it when the user asks for it, or when a change
lands in a shared schema and nobody has said who consumes it.

```
hausgold-sdk: drop plan_id from create and update, add allowed_stripe_price_ids to portal
autopilot: subscription_v1 no longer carries plan_id
```

## Finding the elements

Read the diff, then filter to declaration lines rather than reading whole
files:

```sh
jj diff -r <rev> --git app config db | \
  rg -n '^(\+\+\+|[-+] *(requires|optional|expose |def |enum |validates |scope |t\.))'
```

The pattern is a starting point per stack, not a rule. Confirm each hit in
context: a signature can change through a default, a type, or a keyword that
no single grep catches.

## Common mistakes

- **Listing every touched file.** A file with only implementation changes does
  not appear at all.
- **Explaining why.** The rationale belongs in the commit or the review
  conversation. This document answers what a caller must change.
- **Mixing risk into the layers.** Keep the consumer impact in its own section
  so the layers stay scannable.
- **Stopping at code.** Schemas and migrations are contracts too, and they
  break consumers no compiler warns about.
