# note-format Specification

## Purpose
Defines the on-disk handoff note: its filename and location, the section
vocabulary it uses, and the round-trip rules that keep a human-written note
intact across saves.

## Requirements

### Requirement: Note filename and location
The tool SHALL read and write the note as `.carrot.md` in the repository root, falling back to the current directory when no repository is present. The location SHALL NOT depend on the directory the command runs from.

#### Scenario: Note resolves to the repository root
- **WHEN** a command reads or writes the note from a subdirectory of a repository
- **THEN** the note is `<repository root>/.carrot.md`

#### Scenario: No repository falls back to the working directory
- **WHEN** no repository is present
- **THEN** the note is `.carrot.md` in the current directory and the command still completes

### Requirement: Canonical sections in fixed order
The note SHALL render six canonical sections in this order: Task, State, Decisions, Tried and failed, Next action, Open questions. A heading that differs only in case or punctuation from one of these SHALL be treated as that section.

#### Scenario: Rendering writes all six headings
- **WHEN** a note is rendered
- **THEN** the six canonical headings appear once each, in the documented order

#### Scenario: Heading normalisation
- **WHEN** a note contains `## TASK` or `## tried-and-failed`
- **THEN** the body is read as the Task or Tried and failed section respectively

### Requirement: Tolerant parsing
Parsing SHALL never raise on malformed note text. A missing canonical section SHALL read as empty, an unrecognised `##` heading SHALL be preserved under the wording the author used, and a second body that normalises onto an already-used section SHALL be kept rather than overwrite the first.

#### Scenario: A missing section reads as empty
- **WHEN** a note has no Open questions heading
- **THEN** the note parses and that section reads as an empty string

#### Scenario: An unrecognised heading is preserved
- **WHEN** a note contains `## Deployment notes` with a body
- **THEN** the heading and body are kept and written back after the canonical sections

#### Scenario: Colliding headings keep both bodies
- **WHEN** two headings normalise to the same section
- **THEN** the first body stays in that section, the second is written back at the end of the note, and a warning names both headings

### Requirement: Author text survives a save
A save SHALL preserve what the author wrote outside the machine-derived State section: text before the first heading, the heading wording they used, hand-written extra sections, and a colliding second body.

#### Scenario: Preamble is written back
- **WHEN** a note begins with text before its first `##` heading and is saved
- **THEN** the text still appears before the first heading afterwards

#### Scenario: Hand-written section survives
- **WHEN** a note has a `## Deployment notes` section and is saved
- **THEN** the section is still present with its original heading and body

### Requirement: Prompts and idempotent saves
An unwritten human section SHALL hold a `_TODO:` prompt, and a section still holding its prompt SHALL count as empty. Saving a note twice with no content change SHALL leave the file byte-identical.

#### Scenario: A fresh note holds prompts
- **WHEN** a note is created without a task
- **THEN** each human section holds a `_TODO:` prompt and status reports `0/5 written`

#### Scenario: Repeated saves are byte-identical
- **WHEN** `save` runs twice with the same content and unchanged repository state
- **THEN** the second run leaves the note byte-identical to the first

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

### Requirement: Invalid UTF-8 is read as replacement
Text that is not valid UTF-8 SHALL be read as U+FFFD without raising, and the parse SHALL count the bytes replaced so that a later save can report how many were changed.

#### Scenario: Bytes are counted and reported
- **WHEN** a note contains bytes that are not valid UTF-8 and `save` runs
- **THEN** the tool prints how many bytes it replaced and the note still parses

#### Scenario: Parsing does not raise
- **WHEN** a note holds an invalid byte
- **THEN** `load` prints the note and exits 0 rather than failing with a backtrace

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
