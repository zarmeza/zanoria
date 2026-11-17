# Proposal

## Why

The note is append-only. This repository's own `.carrot.md` is 71 KB and 1,141
lines, with `Decisions` alone at 613; `load` prints all of it, harnesses show a
preview, and an agent that read only the preview reported settled items as
pending work. #8 asked for a size warning and somewhere for old rounds to go.
The blocker was never the warning — it was the boundary: how the tool knows a
round is over. Deriving it from `git log -S` was rejected after this repo's own
history rewrite, and date-slicing was rejected because it cuts a live task in
half. The note will record its own round start instead.

## What Changes

- The Task section carries a machine-written `_Started: YYYY-MM-DD_` line,
  written once and reset only by `save --replace-task`.
- A new `zanoria archive` command moves dated `###` blocks from `Decisions` and
  `Tried and failed` that are older than the start into `.carrot-archive.md`
  beside the note.
- `State` names the archive when it exists, so `load` reveals where earlier
  rounds went.
- `status` warns past 32 KiB and names `zanoria archive` as the remedy.
- Dispatch and help know `archive`.
- A note without `_Started:` parses and saves exactly as it does today.

## Capabilities

### New Capabilities

- `handoff-archive`: the archive command, the sibling file, what moves, and the
  refusals that keep archiving safe.

### Modified Capabilities

- `note-format`: the `_Started:` line in Task, and the archive pointer in State.
- `handoff-save`: backfilling the start and resetting it only on
  `--replace-task`.
- `handoff-init`: recording the start when the note is created.
- `handoff-read`: the size warning in `status`.
- `cli-surface`: the `archive` command in dispatch and help.

## Impact

`lib/zanoria/record.rb`, `template.rb`, `save.rb`, `init.rb`, `status.rb`,
`cli.rb`, and a new `lib/zanoria/archive.rb`. New `spec/archive_spec.rb` plus
coverage in `record_spec`, `template_spec`, and `cli_spec`. README and
`USAGE` gain the command. No dependency change; the archive is plain markdown
and the start is a date, not a database.
