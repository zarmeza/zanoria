# Tasks

## 1. Add the finding

- [x] 1.1 Add a non-destructive `Lint` finding for settled `Open questions` items
- [x] 1.2 Cover the marker set and the non-matches in `spec/lint_spec.rb`
- [x] 1.3 Cover the `status` output in `spec/cli_spec.rb`
- [x] 1.4 Show it red first: remove the finding, confirm only the new examples fail, restore

## 2. Verify

- [x] 2.1 Run `bundle exec rake`
- [x] 2.2 Run `openspec validate warn-settled-questions --strict`
- [x] 2.3 Archive the change and run `openspec validate --specs --strict`
