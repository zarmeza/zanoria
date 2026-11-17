# Spec Delta

## ADDED Requirements

### Requirement: Save maintains the round start
A save SHALL write `_Started:` with the current date when the note has none, SHALL preserve the recorded date on every other save, and SHALL reset it to the current date only when `--replace-task` is given. The backfill SHALL happen once, so repeated saves of unchanged content stay byte-identical.

#### Scenario: The first save records the start
- **WHEN** the first save runs on a note without `_Started:`
- **THEN** the note gains today's date

#### Scenario: A reworded task keeps the start
- **WHEN** a later save rewrites the Task without `--replace-task`
- **THEN** the recorded date is unchanged

#### Scenario: Replacing the task starts a round
- **WHEN** `save --replace-task` runs
- **THEN** the recorded date becomes today

#### Scenario: The backfill is not repeated
- **WHEN** `save` runs twice with no content change
- **THEN** the second run leaves the note byte-identical
