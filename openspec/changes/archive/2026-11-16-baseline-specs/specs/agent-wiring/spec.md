# Spec Delta

## Purpose

The instructions that make a note discoverable: a marked block written into the
repository's agent instruction files, replaced in place, and kept in sync with
its copy in the README.

## ADDED Requirements

### Requirement: The block is inserted with its markers
The block SHALL be written between its begin and end markers, creating the file when absent and appending it after existing content separated by exactly one blank line, with one trailing newline.

#### Scenario: A new file holds only the block
- **WHEN** the block is applied to a file that does not exist
- **THEN** the file is created with the block and one trailing newline

#### Scenario: Existing content is kept
- **WHEN** the block is applied to a file with other content and no markers
- **THEN** the existing content is unchanged and the block follows it after one blank line

### Requirement: An existing block is replaced in place
When the file already holds a marked block, applying the block SHALL replace only the region between the markers and SHALL leave every byte outside them unchanged.

#### Scenario: Surrounding bytes survive
- **WHEN** the block is applied to a file with text before and after an existing marked block
- **THEN** both surrounding regions are byte-identical afterwards

### Requirement: Wiring is idempotent
Applying the same block to the same file twice SHALL leave the file byte-identical, with no extra blank lines.

#### Scenario: A second run changes nothing
- **WHEN** `init` runs twice on the same repository
- **THEN** the instruction files are byte-identical after both runs

### Requirement: The README copy is generated
The README's documented copy of the block SHALL be produced from the same constant by `rake docs:sync`, and the suite SHALL assert that re-embedding the README leaves it unchanged. The documentation markers SHALL remain distinct from the wiring markers.

#### Scenario: Drift is red
- **WHEN** the block changes and `rake docs:sync` does not run
- **THEN** the suite fails on the README fixed-point assertion

#### Scenario: Sync repairs it
- **WHEN** `rake docs:sync` runs after a block change
- **THEN** the README region matches the block and the assertion passes
