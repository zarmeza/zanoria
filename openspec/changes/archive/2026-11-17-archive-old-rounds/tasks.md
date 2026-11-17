# Tasks

## 1. Record the round start

- [x] 1.1 Parse and render `_Started:` as Task metadata, leaving a malformed line in the task text
- [x] 1.2 Backfill the start on save and reset it only on `--replace-task`
- [x] 1.3 Write the start when `init` creates the note
- [x] 1.4 Cover parsing in `spec/record_spec.rb` and rendering in `spec/template_spec.rb`
- [x] 1.5 Cover save and init behaviour in `spec/cli_spec.rb`

## 2. Archive

- [x] 2.1 Add `Zanoria::Archive` to move dated blocks and group them by section
- [x] 2.2 Add the `archive` command to dispatch and help
- [x] 2.3 Name `.carrot-archive.md` in State when it exists
- [x] 2.4 Cover the move, append, refusal and idempotence in `spec/archive_spec.rb`
- [x] 2.5 Cover the command path in `spec/cli_spec.rb`

## 3. Warn

- [x] 3.1 Warn in `status` past 32 KiB, naming `zanoria archive`
- [x] 3.2 Cover the warning and its silence in `spec/cli_spec.rb`

## 4. Verify

- [x] 4.1 Show the boundary red first: remove the date comparison, confirm the move examples fail, restore
- [x] 4.2 Run `bundle exec rake`
- [x] 4.3 Run `openspec validate archive-old-rounds --strict`
- [x] 4.4 Archive the change and run `openspec validate --specs --strict`
