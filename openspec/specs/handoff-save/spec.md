# handoff-save Specification

## Purpose
Writing the note: what a save replaces, the writes it refuses because they would
destroy text, and what it says about durability afterwards.

## Requirements

### Requirement: Save updates the note in place
`save` SHALL create the note when absent and otherwise update the existing note. A task argument SHALL replace the whole Task section; with no task argument the existing Task SHALL be kept. Every other section SHALL be preserved, including hand-written extras.

#### Scenario: Task argument replaces the section
- **WHEN** `save "new task"` runs on a note whose Task holds one paragraph
- **THEN** the Task section holds `new task`

#### Scenario: No argument keeps the task
- **WHEN** `save` runs with no task argument
- **THEN** the Task section holds the text it held before

#### Scenario: Other sections survive
- **WHEN** `save` runs on a note with Decisions text and a hand-written section
- **THEN** both are still present afterwards

### Requirement: Save refuses to drop Task text
A save with a task argument SHALL refuse and write nothing when the existing Task holds more than its first paragraph and the argument would lose later paragraphs. A one-paragraph Task SHALL be replaceable without a flag, and `--replace-task` SHALL override the refusal.

#### Scenario: A multi-paragraph Task is protected
- **WHEN** `save "short"` runs and Task holds a second paragraph
- **THEN** the save refuses, names the paragraph that would be lost, and the file is unchanged

#### Scenario: The override replaces it
- **WHEN** `save --replace-task "short"` runs in the same situation
- **THEN** the Task section holds `short`

### Requirement: Save refuses destructive structural changes
A save SHALL refuse and write nothing when the note holds content the save would silently delete, currently a `###` block inside the machine-derived State section, and SHALL tell the reader where the content can live instead.

#### Scenario: A subheading in State blocks the save
- **WHEN** the note holds a `###` block inside State and `save` runs
- **THEN** the save refuses, the message names the State problem, and the file is byte-identical

### Requirement: Save reports replaced bytes
When the note read by a save held bytes that were not valid UTF-8, the save SHALL report how many bytes it replaced with the replacement character.

#### Scenario: The loss is announced
- **WHEN** a note holds invalid bytes and `save` runs
- **THEN** the output includes the number of bytes replaced

### Requirement: Save reports durability
After writing, `save` SHALL say whether the note is tracked or untracked and remind the reader to commit it. Outside a repository it SHALL warn that the note will not survive a machine swap.

#### Scenario: An untracked note is a reminder
- **WHEN** `save` runs in a repository where the note is untracked
- **THEN** the output says it is untracked and asks for a commit

#### Scenario: No repository warning
- **WHEN** `save` runs outside a repository
- **THEN** the output warns the note will not survive a machine swap
