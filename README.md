# carrot-handoff

Carry a task between AI coding agents without losing the thread.

You are working with one agent until it runs out of tokens, then you switch to
another, and the reasoning that got you halfway died with the session.
`carrot-handoff` puts the state of the task in a file next to the code, so the
next agent can pick it up cold.

The two agents do not have to be different tools. The same use case shows up
when a session dies for reasons that have nothing to do with tokens — a dropped
connection, a power cut, a machine that had to be rebooted — and you come back
to the same agent with none of the thread. From the note's point of view it is
the identical problem.

The note is `.carrot.md`, committed to the repo. It is plain markdown on
purpose: any agent can read it without an integration, a plugin, or a hook.

[![CI](https://github.com/zarmeza/carrot-handoff/actions/workflows/ci.yml/badge.svg)](https://github.com/zarmeza/carrot-handoff/actions/workflows/ci.yml)
[![Ruby](https://img.shields.io/badge/ruby-4.0.7-red.svg)](https://www.ruby-lang.org/)

## Usage

```console
$ carrot-handoff save "Upgrade omniauth-facebook"
Wrote /home/zarmeza/Developer/omnisearch-rails/.carrot.md (untracked — commit it so the next tool sees it)

$ carrot-handoff status
task:     Upgrade omniauth-facebook
file:     /home/zarmeza/Developer/omnisearch-rails/.carrot.md
sections: 1/5 written

$ carrot-handoff load
## Task

Upgrade omniauth-facebook

## State

- Branch: `develop`
- HEAD: `4f18f26`
- Worktree: clean
...
```

| Command | Does |
|---|---|
| `carrot-handoff save [TASK]` | Write or update the note. Preserves sections you already wrote. |
| `carrot-handoff load` | Print the note. |
| `carrot-handoff status` | Task summary plus how many of the five human sections are filled. `State` is machine-derived and not counted. |
| `carrot-handoff clear` | Delete the note. |
| `carrot-handoff path` | Print the note's absolute path. |

Aliases: `new` for `save`, `show`/`cat` for `load`, `st` for `status`, `rm` for
`clear`.

## The format

Six sections. Three of them a machine fills in, three only you or an agent can.

| Section | Filled by | Holds |
|---|---|---|
| `Task` | you | What this is, for someone with no history. |
| `State` | git | Branch, HEAD, uncommitted files, recent commits. Regenerated on every save. |
| `Decisions` | you | Choices made and rejected. |
| `Tried and failed` | you | What did not work, and why. **The section that matters most.** |
| `Next action` | you | The single next step. |
| `Open questions` | you | Unknown, unverified, blocked. |

`Tried and failed` is the reason this tool exists. Two agents handed the same
task will independently retry the same dead end unless somebody wrote down that
it was tried. That information exists nowhere else.

Empty sections get a `_TODO:` prompt rather than being omitted, so the shape of
the note is visible. Prompts are regenerated on each save and never accumulate
as content, which makes repeated `save` calls idempotent.

Any heading `carrot-handoff` does not recognize is kept, and `status` lists it
under `extra:` so a hand-written section is never silently dropped.

## Wiring it into an agent

There is nothing to install. Two lines in the project's `AGENTS.md` is enough:

```markdown
Before starting work in this repository, run `carrot-handoff load`. If a note
exists, it describes work already in progress — read it and follow its
`Next action`.

Before you finish, run `carrot-handoff save "<one-line task>"` and fill in the
`Tried and failed` and `Decisions` sections with what you actually learned.
```

Commit the note. That is what makes it survive a context reset and a machine
swap.

### Outside a git repository

`save` writes to the current directory when there is no repository, and says so:

```console
$ cd ~/somewhere/not/a/repo
$ carrot-handoff save "Investigate the flaky spec"
Wrote /home/zarmeza/somewhere/not/a/repo/.carrot.md (no git repository here — this note will not
survive a machine swap. Move it into a repo to make it durable.)
```

A note in the wrong place is recoverable by moving it. No note is not, and the
whole point of the tool is that there is one.

## Why not OpenWolf?

OpenWolf does something similar and is more capable: native hooks for Claude
Code and Codex, project maps, token accounting, a dashboard. Two reasons this
exists instead:

- **Hook support for antigravity is instructions-only.** OpenWolf's own docs
  list Antigravity alongside Cursor and Gemini CLI under "project instruction
  files", with no full hook integration. Half the tool for a two-tool handoff.
- **List-price accounting does not model a free-tier ceiling.** The constraint
  here is tokens running out, not money spent.

This is also AGPL-3.0-free, which matters if it ever ends up somewhere real.

## Development

```console
$ bundle install
$ bundle exec rake        # specs + rubocop
$ bundle exec rspec       # 50 examples
$ bundle exec rubocop
```

Installed locally with `gem install`, so the `carrot-handoff` command works from
any directory. It is a snapshot of a release rather than a link to the checkout,
so rebuild and reinstall after changing `lib/`:

```console
$ gem build carrot-handoff.gemspec && gem install ./carrot-handoff-*.gem
```

Ruby 4.0.7. No runtime dependencies — `open3` and `json` are stdlib.

Specs build real throwaway git repositories in a tmpdir rather than stubbing
`CarrotHandoff::Git`, so the shell-outs are actually exercised.

CI runs three jobs on every push: **Specs**, **RuboCop**, and a **CLI smoke
test** that drives `bin/carrot-handoff` in a throwaway repo — `help`, a
save/status/load round trip, and a check that it exits non-zero outside a
repository. Specs passing on one laptop is not evidence for anyone else, and a
portfolio project needs the evidence to be reproducible.

## Layout

```text
bin/carrot-handoff             entry point
lib/carrot_handoff.rb          FILENAME, Repo (path lookups), Error
lib/carrot_handoff/git.rb      git binary wrapper; returns nil, never raises
lib/carrot_handoff/record.rb   markdown in, sections out
lib/carrot_handoff/store.rb    file IO
lib/carrot_handoff/template.rb note rendering, git state assembly
lib/carrot_handoff/cli.rb      argument dispatch
spec/                          45 examples
.carrot.md                     this repo's own handoff note
AGENTS.md                      conventions for agents working here
```
