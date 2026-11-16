# handoff-init Specification

## Purpose
One-time setup for a repository: create the note when it is absent, wire the
agent instruction files, and stage what landed inside the repository.

## Requirements

### Requirement: init never overwrites the note
`init` SHALL create the note from the template when none exists, using the TASK argument as the Task body. When a note already exists it SHALL leave the file byte-for-byte unchanged and SHALL ignore TASK.

#### Scenario: A missing note is created
- **WHEN** `init "fix the parser"` runs where no note exists
- **THEN** a note is created whose Task section holds `fix the parser`

#### Scenario: An existing note is kept
- **WHEN** `init "a different task"` runs where a note already exists
- **THEN** the note is byte-identical to what it was before and TASK is ignored

### Requirement: Instruction files follow the repository
`init` SHALL wire whichever of `AGENTS.md` and `CLAUDE.md` the repository already has, SHALL create `AGENTS.md` when it has neither, and SHALL wire exactly the paths named by repeated `--file` or `--file=PATH` instead of detecting any.

#### Scenario: Only the existing files are wired
- **WHEN** a repository has `CLAUDE.md` and no `AGENTS.md`
- **THEN** the block is written into `CLAUDE.md` and no `AGENTS.md` is created

#### Scenario: Both files are wired
- **WHEN** a repository has both `AGENTS.md` and `CLAUDE.md`
- **THEN** the block is written into both

#### Scenario: Neither file exists
- **WHEN** a repository has neither instruction file
- **THEN** `AGENTS.md` is created with the block

#### Scenario: --file replaces detection
- **WHEN** `init --file docs/AGENTS.md` runs and `docs/` does not exist
- **THEN** the directory is created and only that file is wired

### Requirement: init stages only what is inside the repository
`init` SHALL stage the note and the wired files that resolve inside the repository, SHALL report paths outside it as left unstaged, and SHALL stage nothing when no repository is present.

#### Scenario: A path outside the repository is not staged
- **WHEN** `init --file ../AGENTS.md` runs inside a repository
- **THEN** the outside file is reported as left unstaged and the run succeeds

#### Scenario: No repository
- **WHEN** `init` runs outside a repository
- **THEN** the note and wiring are written and the output warns the note will not survive a machine swap

### Requirement: init reports what it did
`init` SHALL report the note as created or kept, each wired file as created, wired or already current, the staged paths, every path git refused with git's reason, and a suggested commit that names only the paths that reached the index.

#### Scenario: Re-running init is idempotent
- **WHEN** `init` runs twice with unchanged files
- **THEN** the second run reports every file as already current and changes no bytes

#### Scenario: A refused path is reported
- **WHEN** git refuses to stage a wired path
- **THEN** the output names the path and git's reason, and the suggested commit does not name it
