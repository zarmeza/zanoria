# Spec Delta

## ADDED Requirements

### Requirement: status warns when the note is large
`status` SHALL warn when the note file exceeds 32 KiB (32,768 bytes), naming `zanoria archive` as the remedy. The warning SHALL be non-destructive and SHALL NOT block a save.

#### Scenario: A large note is reported
- **WHEN** the note is larger than 32 KiB and `status` runs
- **THEN** a `warning:` line names `zanoria archive`

#### Scenario: A small note stays silent
- **WHEN** the note is 32 KiB or smaller
- **THEN** no size warning is printed

#### Scenario: The warning does not block a save
- **WHEN** the note is larger than 32 KiB and `save` runs
- **THEN** the note is written
