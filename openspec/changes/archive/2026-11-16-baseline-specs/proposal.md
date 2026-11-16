# Proposal

## Why

Eight rounds of behaviour have shipped — the note format, the commands, the
wiring block, the git reporting, the release guards — and none of it is written
down as a contract. The rules live in code comments and in a handoff note that
describes one task, not the tool. A session can change behaviour without knowing
it was deliberate, and a reviewer cannot tell a bug from a decision. Recording
the behaviour that exists today makes every future change a delta against a
stated contract instead of a guess about what was intended.

## What Changes

- Initialize OpenSpec in this repository (`openspec/`, plus the generated
  `.opencode/` workflows).
- Capture the behaviour shipped through `fc326d9` as eight capability specs,
  one per module boundary.
- Define nothing the tool does not already do. This is a baseline, not a
  redesign.
- Leave `lib/`, `spec/`, `bin/` and the gemspec untouched. The only new files
  are under `openspec/` and `.opencode/`.

## Capabilities

### New Capabilities

- `note-format`: the `.carrot.md` file — location, section vocabulary, tolerant
  parsing, round-trip preservation, prompts, machine-derived State, invalid
  bytes.
- `cli-surface`: command dispatch and aliases, help text, exit status, and the
  hidden `moo` command.
- `handoff-init`: one-time setup — note creation without overwrite,
  instruction-file detection, staging scope, and the report.
- `handoff-save`: writing the note — what a save replaces, the refusals that
  protect text, byte replacement, durability report.
- `handoff-read`: `load`, `status`, `clear` and `path` — what they print and
  when they fail.
- `agent-wiring`: the marked instruction block, its in-place replacement,
  idempotence, and the README's generated copy.
- `git-state`: failure-tolerant repository reads, root-anchored path queries,
  the per-path staging report, and the unpushed count.
- `release`: the local and tag guards, published-version parsing, and the single
  key-free publish route.

### Modified Capabilities

None. No existing capability exists yet.

## Impact

Documentation and tooling only. No runtime behaviour changes; `bundle exec rake`
stays the gate. Adds `openspec/` and `.opencode/` to the repository. Future
behaviour changes are expected to start as an OpenSpec change with a delta spec.
