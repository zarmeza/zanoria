# Proposal

## Why

The wiring block and `AGENTS.md` both say `Open questions` holds only what
nobody has decided, but nothing checks. Decided items collect there, and a
reader takes them as pending work — which is exactly what happened when an agent
reported settled items as open. `status` already prints every lint finding, so
the cheapest fix is one more warning rather than a new command or convention.

## What Changes

- `status` gains a warning for a settled `Open questions` item.
- An item is settled when it starts with a settled marker, or is struck through.
- The finding is non-destructive: it never refuses a `save`.
- No format change, no new command, no new dependency.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `handoff-read`: `status` gains a requirement for the settled-item warning.

## Impact

`lib/zanoria/lint.rb` plus specs (`spec/lint_spec.rb`, `spec/cli_spec.rb`).
`status` already prints every lint finding, so no CLI change is expected beyond
the finding itself. The note format is unchanged.
