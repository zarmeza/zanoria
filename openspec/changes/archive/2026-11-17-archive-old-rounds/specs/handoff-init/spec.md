# Spec Delta

## ADDED Requirements

### Requirement: init records the round start
When `init` creates the note it SHALL write `_Started:` with the creation date, including when TASK is supplied. On an existing note it SHALL NOT add or change the line.

#### Scenario: A new note carries the date
- **WHEN** `init` creates a note
- **THEN** the note's Task section holds today's `_Started:` date

#### Scenario: Re-running init leaves it alone
- **WHEN** `init` runs on a note that already exists
- **THEN** the `_Started:` line is byte-identical afterwards
