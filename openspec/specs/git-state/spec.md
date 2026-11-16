# git-state Specification

## Purpose
How the tool reads repository facts and stages files: read-only,
failure-tolerant, independent of the working directory, and explicit about what
reached the index.

## Requirements

### Requirement: Repository reads never raise
Repository reads SHALL return nil or an empty collection on a non-zero exit, empty output, a missing repository, or a missing `git` binary. They SHALL NOT raise, so a note can still be written when git cannot answer.

#### Scenario: No repository
- **WHEN** a read runs outside a repository
- **THEN** it returns nil and the caller still completes

#### Scenario: Detached HEAD
- **WHEN** HEAD is detached
- **THEN** the branch reads as nil and the note is still written

### Requirement: The reported facts
The tool SHALL report the repository root, the current branch, the short HEAD, the uncommitted paths, the five most recent commits, the upstream branch, and the number of commits touching the note that the upstream lacks.

#### Scenario: A normal repository is described
- **WHEN** a note is rendered in a repository with a branch and commits
- **THEN** State names the branch, the short HEAD, the uncommitted files and the recent commits

### Requirement: Path queries are anchored at the root
Queries about whether the note is tracked, and how far ahead of its upstream it is, SHALL resolve the note against the repository root rather than the current directory. A path outside the repository SHALL be passed to git unchanged, which may refuse it.

#### Scenario: Running from a subdirectory
- **WHEN** the tool runs from a subdirectory of a repository whose note is committed
- **THEN** the note is reported as tracked

### Requirement: Staging reports per path
Staging SHALL be attempted one path at a time. Each path SHALL first be checked with `git add --dry-run`, SHALL be reported as staged only when it reached the index, and a refusal SHALL be reported with git's first-line reason.

#### Scenario: An unchanged file is not reported
- **WHEN** a path is already in the index exactly as it is on disk
- **THEN** it is not reported as staged

#### Scenario: A refused path carries a reason
- **WHEN** a path is ignored by git
- **THEN** it is reported as not staged, with git's reason

#### Scenario: One failure does not hide another path
- **WHEN** one path is staged and another is refused
- **THEN** the staged path is reported as staged and the refused one with its reason

### Requirement: The unpushed count distinguishes unknown from zero
The count of note commits ahead of the upstream SHALL be nil when there is no upstream, so a caller can stay silent, and SHALL be a number when an upstream exists, including zero.

#### Scenario: No upstream is not zero
- **WHEN** the branch has no upstream
- **THEN** the count is nil and no unpushed line is printed
