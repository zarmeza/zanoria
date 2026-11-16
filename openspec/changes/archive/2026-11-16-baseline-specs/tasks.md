# Tasks

## 1. Capture the baseline

- [x] 1.1 Initialize OpenSpec and record the capability map in `proposal.md`
- [x] 1.2 Capture the note file contract in `specs/note-format/spec.md`
- [x] 1.3 Capture command dispatch, help and exit status in `specs/cli-surface/spec.md`
- [x] 1.4 Capture setup behaviour in `specs/handoff-init/spec.md`
- [x] 1.5 Capture save behaviour and its refusals in `specs/handoff-save/spec.md`
- [x] 1.6 Capture load, status, clear and path in `specs/handoff-read/spec.md`
- [x] 1.7 Capture the instruction block in `specs/agent-wiring/spec.md`
- [x] 1.8 Capture repository reads and staging in `specs/git-state/spec.md`
- [x] 1.9 Capture the release guards and publish route in `specs/release/spec.md`

## 2. Verify the baseline

- [x] 2.1 Check every requirement against the code in `lib/` and correct the spec where they disagree
- [x] 2.2 Run `openspec validate baseline-specs --strict`
- [x] 2.3 Archive the change and run `openspec validate --specs --strict`
- [x] 2.4 Confirm `bundle exec rake` is still green
