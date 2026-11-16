# release Specification

## Purpose
The checks that stand between a working tree and a published gem, and the single
publish route, which must stay free of stored credentials.

## Requirements

### Requirement: The local release guard
`rake release` SHALL refuse before building or tagging when the worktree is dirty, when the current branch is not `main`, or when the version is already published on RubyGems.

#### Scenario: A dirty worktree stops the release
- **WHEN** the worktree has uncommitted changes
- **THEN** the task aborts and says the worktree is dirty

#### Scenario: A branch other than main stops the release
- **WHEN** the checked out branch is not `main`
- **THEN** the task aborts and names the branch

#### Scenario: A published version cannot be republished
- **WHEN** the version already appears in the published list
- **THEN** the task aborts and says it is already published

### Requirement: The tag guard
The publish workflow SHALL refuse a tag that is not exactly `v<version>`, a tagged commit that is not on `main`, and a version already published on RubyGems.

#### Scenario: A mismatched tag is refused
- **WHEN** the tag is `v0.4.1` and the version is `0.4.0`
- **THEN** the guard refuses with a tag/version mismatch

#### Scenario: A tag off main is refused
- **WHEN** the tagged commit is not an ancestor of `main`
- **THEN** the guard refuses

### Requirement: Published versions are read from the gem list
Published versions SHALL be read only from the parenthesised list printed by `gem list --remote --exact --all <name>`. Output with no parenthesised list SHALL read as no published versions.

#### Scenario: A published gem yields its versions
- **WHEN** the command prints `zanoria (0.4.0, 0.3.0)`
- **THEN** the parsed versions are `0.4.0` and `0.3.0`

#### Scenario: An unpublished gem yields none
- **WHEN** the command prints nothing for the name
- **THEN** no versions are parsed

### Requirement: One key-free publish route
`rake release` SHALL guard, build the gem, create the tag `v<version>`, and push the tag; it SHALL NOT push the gem. The publish workflow SHALL exchange a GitHub OIDC token for a short-lived push token and read no stored API key. It SHALL publish only for a pushed `v*` tag; a manual run SHALL stop before the push.

#### Scenario: The rake task pushes only a tag
- **WHEN** `rake release` completes
- **THEN** the tag exists on the remote and no gem was pushed by the task

#### Scenario: A manual run stops after the exchange
- **WHEN** the Publish workflow is started by hand
- **THEN** it builds and configures credentials but does not run `gem push`
