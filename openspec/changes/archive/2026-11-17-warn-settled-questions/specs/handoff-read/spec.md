# Spec Delta

## ADDED Requirements

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
