# CarrotHandoff Agent Guide

Guidance for AI coding agents working in this repository. Two sections matter:
**Conventions** and **The handoff loop**.

---

## 1. What this is

A small Ruby CLI that writes a committed `.carrot.md` beside the code so a
different agent tool can pick up an in-progress task without the conversation.
Plain markdown output on purpose — no agent integration required to read it.

- Ruby 4.0.7, zero runtime dependencies (`open3` and `json` are stdlib).
- CLI at `bin/carrot-handoff`, implementation in `lib/carrot_handoff/`.

---

## 2. The handoff loop

**This repository is itself a handoff tool, so use it on itself.**

Before starting work:

```console
$ bin/carrot-handoff load
```

If a note exists, it describes work already in progress. Follow its
`Next action`. Do not re-derive what the `Decisions` section already settled.

Before finishing:

```console
$ bin/carrot-handoff save "<one-line task>"
```

Then fill in, by hand, the sections only a human or agent can know:

- `Decisions` — choices made, including options rejected and why.
- `Tried and failed` — what did not work, and why. **The most valuable
  section.** Two agents handed the same task will retry the same dead end
  unless somebody records it. This information exists nowhere else.
- `Next action` — the single next step, specific enough to start cold.
- `Open questions` — anything unverified or blocked.

Commit the note. That is what makes it survive a context reset or a machine
swap. `State` is machine-derived and regenerates on every save; do not edit it.

Save after every real decision rather than only at the end, when work spans
more than one session. An outage costs minutes if the note is already written
and the whole thread if it is not.

---

## 3. Commands

| Command | Does |
|---|---|
| `bin/carrot-handoff save [TASK]` | Write or update the note. Keeps sections. |
| `bin/carrot-handoff load` | Print the note. |
| `bin/carrot-handoff status` | Task plus count of five human sections set. |
| `bin/carrot-handoff clear` | Delete the note. |
| `bin/carrot-handoff path` | Absolute path to the note. |

Outside a git repository the note goes in the current directory and `save`
warns that it will not survive a machine swap. `Repo.root` falls back to
`Dir.pwd` and `Repo.in_repo?` reports which case applies; the CLI no longer
raises for a missing repository.

---

## 4. Commands to run

```console
$ bundle install                       # once
$ bundle exec rake                    # specs + rubocop (default task)
$ bundle exec rspec                   # 45 examples
$ bundle exec rubocop                 # lint
$ ruby -Ilib -e 'require "carrot_handoff"'   # smoke check
```

`bundle exec rake` is the gate: both specs and RuboCop must be clean.

---

## 5. Layout

```text
bin/carrot-handoff             entry point
lib/carrot_handoff.rb          FILENAME, Repo (path lookups), Error
lib/carrot_handoff/git.rb      git binary wrapper; returns nil, never raises
lib/carrot_handoff/record.rb   markdown in, sections out
lib/carrot_handoff/store.rb    file IO
lib/carrot_handoff/template.rb note rendering, git state assembly
lib/carrot_handoff/cli.rb      argument dispatch
spec/                          45 examples
.carrot.md                     current task note (committed)
```

---

## 6. Conventions

**Git access is read-only and must never raise.** `CarrotHandoff::Git` shells
out via `Open3.capture2` with `err: File::NULL` and returns `nil` on any failure
— non-zero exit, empty output, missing binary. Callers handle `nil`, so never
assume a git call succeeded. `CarrotHandoff::Template.observed_state`
additionally rescues `StandardError`, because a failed note is worse than a
partial one.

**Memoize carefully.** `CarrotHandoff::Git.root` caches in `@root`; call
`CarrotHandoff::Git.reset!` after changing directory or the cache goes stale.
Specs do this via the `in_repo` helper, which `chdir`s into a tmpdir git repo.

**Parse tolerantly.** `CarrotHandoff::Record.parse` returns empty strings for
missing sections and keeps unrecognized headings under an `other_` key so a
hand-written section survives a rewrite. Never let a malformed note raise.

**Prompts are not content.** A section still holding `_TODO:` counts as empty.
`CarrotHandoff::Template.body_for` regenerates prompts on every render, which is
what makes repeated `save` calls idempotent. If you add a section, add it to
`CarrotHandoff::Record::SECTIONS` and to `CarrotHandoff::Template::PROMPTS`.

**Specs build real repositories.** Use the `in_repo` helper and `commit_all`
from `spec/spec_helper.rb`. Do not stub `CarrotHandoff::Git` — the point is to
exercise the actual shell-outs. See
`spec/template_spec.rb` for the pattern of stubbing individual readers when
testing a render path.

**RuboCop is clean and stays that way.** Run it before committing. Two
deliberate relaxations live in `.rubocop.yml`: `Metrics/AbcSize` raised to 27
(three linear methods sit just over the default) and `Style/Documentation`
off. Do not add new exclusions without a comment explaining why.

---

## 7. Adding a section

1. Add the key and heading to `CarrotHandoff::Record::SECTIONS`.
2. Add a prompt to `CarrotHandoff::Template::PROMPTS` unless machine-derived.
3. Handle it in `CarrotHandoff::Template.body_for` if it needs custom fill.
4. Add parse coverage in `spec/record_spec.rb`.

Order in `SECTIONS` is both display and write order.
