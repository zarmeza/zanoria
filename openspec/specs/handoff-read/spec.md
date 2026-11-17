# handoff-read Specification

## Purpose
The read-only commands that show the note and its state: `load`, `status`,
`clear` and `path`.

## Requirements

### Requirement: load prints the note verbatim
`load` SHALL print the note file exactly as it is on disk and exit 0. When no note exists it SHALL say so on stderr and exit 1.

#### Scenario: The file is printed as written
- **WHEN** a note exists and `load` runs
- **THEN** the output matches the file contents

#### Scenario: No note is a failure
- **WHEN** no note exists and `load` runs
- **THEN** stderr says there is no note and the exit status is 1

### Requirement: status summarises the note
`status` SHALL print the first line of Task, the note's absolute path, the count of written human sections out of five, any extra sections, and any lint warnings. It SHALL exit 1 and print `no handoff note` when no note exists.

#### Scenario: A written note is summarised
- **WHEN** three human sections hold content and `status` runs
- **THEN** the output includes `sections: 3/5 written` and the task's first line

#### Scenario: Lint findings are surfaced
- **WHEN** the note has a `###` block in State
- **THEN** `status` prints a `warning:` line describing it

#### Scenario: Missing note
- **WHEN** no note exists and `status` runs
- **THEN** the output is `no handoff note` and the exit status is 1

### Requirement: status reports unpushed note commits
`status` SHALL print an `unpushed:` line when commits touching the note exist on the branch and not on its upstream. It SHALL print nothing when the note has no unpushed commits or when there is no upstream.

#### Scenario: Unpushed commits are counted
- **WHEN** the branch has commits touching the note that its upstream lacks
- **THEN** `status` prints `unpushed: N note commit(s) ahead of <upstream>`

#### Scenario: No upstream stays silent
- **WHEN** the branch has no upstream
- **THEN** `status` prints no unpushed line

### Requirement: clear removes the note
`clear` SHALL delete the note and exit 0. When no note exists it SHALL say there is nothing to clear and still exit 0.

#### Scenario: Removing an existing note
- **WHEN** a note exists and `clear` runs
- **THEN** the file is gone and the exit status is 0

#### Scenario: Nothing to remove
- **WHEN** no note exists and `clear` runs
- **THEN** the output says nothing was cleared and the exit status is 0

### Requirement: path prints the note location
`path` SHALL print the absolute path of the note, whether or not the file exists, and exit 0.

#### Scenario: The path is printed without a note
- **WHEN** no note exists and `path` runs
- **THEN** the absolute path is printed and the exit status is 0

### Requirement: status warns about settled open questions
`status` SHALL warn when an `Open questions` item is settled. An item is settled when its text, after any list marker and emphasis, begins with `Resolved:`, `Resolved —`, `Addressed in`, `Decided:`, `Settled:`, `Deliberate`, `On purpose`, or is struck through. The warning SHALL name the item and say settled items belong in `Decisions`. The finding SHALL be non-destructive, and prose that merely contains one of those phrases SHALL NOT trigger it.

#### Scenario: A resolved item is reported
- **WHEN** `Open questions` holds `- **Resolved:** publishing is paused` and `status` runs
- **THEN** a `warning:` line names that item and says it belongs in `Decisions`

#### Scenario: A struck-through item is reported
- **WHEN** `Open questions` holds `- ~~Where do archived rounds go?~~`
- **THEN** the item is reported as settled

#### Scenario: Prose does not trigger the warning
- **WHEN** an open item reads `- Do I no longer need the retry wrapper?`
- **THEN** no settled-item warning is printed

#### Scenario: Decisions is not scanned
- **WHEN** `Decisions` holds a `Resolved:` item and `Open questions` is empty
- **THEN** no settled-item warning is printed

#### Scenario: The warning does not block a save
- **WHEN** a settled item is present and `save` runs
- **THEN** the note is written and the finding does not refuse the save
