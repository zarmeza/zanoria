# Design

## Context

See `proposal.md` — Why. The note is a flat list of `##` sections; `State` is
regenerated from git on every save; `save` rewrites the whole file; parsing is
tolerant. There is no round marker and no archive, so the only boundary
available today is a date in a `###` heading, which says nothing about whether
the round that wrote it is over.

## Goals / Non-Goals

**Goals:** a recorded boundary that survives a clone; an explicit archive
command; a size warning with a remedy; notes without the new line unaffected.

**Non-Goals:** automatic archiving; archiving `Open questions` or `Next action`;
an index of rounds; `load SECTION` (#11); rewriting or summarising history.

## Decisions

- **Record the start; do not derive it.** `git log -S` on the Task line was
  rejected: this repo has had a history rewrite, CI checks out shallow, and a
  reworded Task reads as a new round. Date-slicing was rejected because it cuts
  a live task in half. A line in the note is visible, committed with it, and
  survives any clone.
- **`--replace-task` is the new-round signal.** It is the one flag that already
  means "discard the old Task on purpose"; a reword is not a new round. A new
  `--new-round` flag was rejected as a second way to write a task for one
  meaning, and resetting on any task argument was rejected because rewording
  would archive the live round.
- **Archiving is explicit.** The tool cannot know a round is over. A command is
  deterministic, and the size warning gives it a discoverable path. Automatic
  archiving on save was rejected: a save that moves content the author did not
  ask about is the kind of surprise the tool avoids elsewhere.
- **Only `Decisions` and `Tried and failed` are archived.** They hold the dated
  rounds. `Open questions` is pending work — archiving it would hide open items
  — and `Next action` is current by definition.
- **The archive is a plain markdown sibling, `.carrot-archive.md`.** It is
  committed next to the note and groups moved blocks under the section they came
  from. A per-round file was rejected because `load` needs a stable name; a
  directory adds one more thing to discover.
- **The pointer lives in `State`.** `State` is regenerated, so the pointer costs
  no storage and cannot go stale. `load` prints it because `load` prints the
  file verbatim.

## Risks / Trade-offs

- **A round boundary inside one day is ambiguous** → conservative: blocks dated
  the start date stay in the live note.
- **`--replace-task` by habit resets the boundary** → archiving is explicit, so
  nothing moves until a second command; the date is visible in the note.
- **The first archive here moves ~30 blocks at once** → the text is preserved,
  the archive is committed, and the size warning only fires once the remedy
  exists.
- **A hand-edited `_Started:` date changes what moves** → both files are
  committed, so the move is reviewable in the diff.

## Migration Plan

Notes without `_Started:` are backfilled on their next save, or on `init` when
the note is created. The first archive is manual. Rollback is
`git checkout -- .carrot.md .carrot-archive.md`: both files are committed, and
no other state is involved.
