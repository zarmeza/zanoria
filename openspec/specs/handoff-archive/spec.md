# handoff-archive Specification

## Purpose
Moving earlier rounds out of the live note: an explicit command that writes dated
blocks to a sibling archive, so `load` stays short without losing the reasoning.

## Requirements

### Requirement: Archive moves rounds older than the recorded start
The `archive` command SHALL move every dated `###` block in `Decisions` and `Tried and failed` whose date is before the note's `_Started:` date into `.carrot-archive.md` beside the note. Blocks dated on or after the start, and blocks without a date, SHALL stay in the live note. The moved text SHALL NOT be rewritten.

#### Scenario: An older block moves
- **WHEN** `Decisions` holds a block dated before the start and `archive` runs
- **THEN** the block is gone from the live note and present in the archive under `## Decisions`

#### Scenario: The current round stays
- **WHEN** a block is dated on or after the start
- **THEN** it stays in the live note

#### Scenario: An undated block stays
- **WHEN** a `###` block in either section has no date
- **THEN** it stays in the live note

### Requirement: Archive appends and does not duplicate
An existing archive SHALL be appended to rather than overwritten, a block already present SHALL NOT be written twice, and running `archive` twice with no new old blocks SHALL leave both files byte-identical. When there is nothing to move, nothing SHALL be written and the command SHALL say so.

#### Scenario: Existing archive content survives
- **WHEN** `.carrot-archive.md` already holds earlier blocks and a new old block is moved
- **THEN** the earlier blocks are unchanged and the new one is added

#### Scenario: A second run is byte-identical
- **WHEN** `archive` runs twice with no intervening change
- **THEN** the live note and the archive are both byte-identical after the second run

#### Scenario: Nothing to move
- **WHEN** every dated block is from the current round
- **THEN** nothing is written and the command says there is nothing to archive

### Requirement: Archive refuses without a start
If the note has no `_Started:` line, `archive` SHALL write nothing and SHALL say that the next save records the start. If there is no note at all, it SHALL exit 1.

#### Scenario: No start date
- **WHEN** the note has no `_Started:` line and `archive` runs
- **THEN** both files are unchanged and the message names the next save

#### Scenario: No note
- **WHEN** no note exists and `archive` runs
- **THEN** the exit status is 1

### Requirement: Archive keeps the text readable
The archive SHALL be plain markdown: a title, and each moved block under the heading of the section it came from.

#### Scenario: The text is not summarised
- **WHEN** a block is moved
- **THEN** the archive holds the block's original text and heading
