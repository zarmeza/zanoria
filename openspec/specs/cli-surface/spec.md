# cli-surface Specification

## Purpose
Defines the command-line contract: the commands and aliases that exist, how
arguments are interpreted, what is printed on failure, and the exit status a
caller can rely on.

## Requirements

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

### Requirement: Exit status and failure output
Every command SHALL exit 0 on success and 1 on a handled failure. A failure the tool raises SHALL be printed as `zanoria: <message>` on stderr and SHALL NOT produce a backtrace.

#### Scenario: A handled failure is reported
- **WHEN** a command cannot read the note
- **THEN** stderr holds `zanoria: could not read <path>: <reason>` and the exit status is 1

### Requirement: Help text documents the visible surface
The help text SHALL list `init`, `save`, `load`, `status`, `clear`, `path`, `archive` and `help`, SHALL describe `init --file` and `save --replace-task`, and SHALL NOT mention `moo`.

#### Scenario: Help lists the commands
- **WHEN** the user runs `zanoria help`
- **THEN** each documented command, including `archive`, appears in the usage text

#### Scenario: Help hides the easter egg
- **WHEN** the usage text is printed
- **THEN** the word `moo` does not appear in it

### Requirement: moo is a hidden easter egg
`moo` SHALL print the art, exit 0, and read or write no note and no repository state. It SHALL stay absent from the help text.

#### Scenario: moo prints and changes nothing
- **WHEN** the user runs `zanoria moo` in a repository
- **THEN** the art is printed, the exit status is 0, and the worktree is byte-identical afterwards
