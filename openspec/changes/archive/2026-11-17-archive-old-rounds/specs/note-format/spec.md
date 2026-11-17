# Spec Delta

## ADDED Requirements

### Requirement: Task records when the round started
The Task section SHALL carry the round's start as a machine-written `_Started: YYYY-MM-DD_` line. Parsing SHALL expose the date as metadata rather than task text, and SHALL NOT count the line as a paragraph. A note without the line SHALL parse normally, and a `_Started:_` line that does not hold a date SHALL stay in the task text so a save cannot delete it.

#### Scenario: The start is read as metadata
- **WHEN** a Task section holds `Ship #8.` followed by `_Started: 2026-11-17_`
- **THEN** the task text is `Ship #8.` and the start date is `2026-11-17`

#### Scenario: A note without a start parses
- **WHEN** a note has no `_Started:_` line
- **THEN** it parses normally and the start date is absent

#### Scenario: A malformed start is not discarded
- **WHEN** the Task holds `_Started: soon_`
- **THEN** the line stays in the task text

## MODIFIED Requirements

### Requirement: State is machine-derived
The State section SHALL be rebuilt from repository facts on every render and SHALL NOT preserve authored text. It SHALL report the branch and HEAD, uncommitted paths with a cap of twenty plus a remainder count, the five most recent commits, SHALL name `.carrot-archive.md` when that file exists beside the note, and SHALL say when the repository has no commits or none was found.

#### Scenario: Uncommitted work is reported
- **WHEN** the worktree has uncommitted files and a note is rendered
- **THEN** State lists the count and the paths, and lists the recent commits

#### Scenario: A repository with no commits
- **WHEN** the repository has no commits yet
- **THEN** State says the repository has no commits rather than claiming no repository

#### Scenario: Authored text in State is not preserved
- **WHEN** State holds a `###` block and the note is read with `status`
- **THEN** `status` warns that the next save will delete it

#### Scenario: The archive is named
- **WHEN** `.carrot-archive.md` exists beside the note and the note is rendered
- **THEN** State names `.carrot-archive.md`
