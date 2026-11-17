# Spec Delta

## MODIFIED Requirements

### Requirement: Command dispatch and aliases
The CLI SHALL dispatch `init`, `save`, `load`, `status`, `clear`, `path`, `archive`, `help` and `moo`, together with the aliases `setup`, `new`, `show`, `cat`, `st`, `rm`, `-h` and `--help`. An unknown command SHALL print an error and the usage text and SHALL exit non-zero.

#### Scenario: An alias runs its command
- **WHEN** the user runs `zanoria st`
- **THEN** the status summary is printed

#### Scenario: An unknown command is rejected
- **WHEN** the user runs `zanoria frobnicate`
- **THEN** `zanoria: unknown command "frobnicate"` is printed with the usage text and the exit status is 1

#### Scenario: No arguments prints usage
- **WHEN** the user runs `zanoria` with no arguments
- **THEN** the usage text is printed and the exit status is 0

#### Scenario: The archive command is dispatched
- **WHEN** the user runs `zanoria archive`
- **THEN** the archive command runs

### Requirement: Help text documents the visible surface
The help text SHALL list `init`, `save`, `load`, `status`, `clear`, `path`, `archive` and `help`, SHALL describe `init --file` and `save --replace-task`, and SHALL NOT mention `moo`.

#### Scenario: Help lists the commands
- **WHEN** the user runs `zanoria help`
- **THEN** each documented command, including `archive`, appears in the usage text

#### Scenario: Help hides the easter egg
- **WHEN** the usage text is printed
- **THEN** the word `moo` does not appear in it
