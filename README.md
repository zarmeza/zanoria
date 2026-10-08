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

Start a repo once:

```console
$ cd ~/Developer/my-project && git init
$ carrot-handoff init "Upgrade omniauth-facebook"
Initialized handoff for /home/zarmeza/Developer/my-project
  .carrot.md created
  AGENTS.md  wired
Staged AGENTS.md .carrot.md
Commit it so the next tool sees it:
  git commit -m "chore: add .carrot.md"
```

Then save and load as work happens:

```console
$ carrot-handoff save "Upgrade omniauth-facebook"
Wrote /home/zarmeza/Developer/my-project/.carrot.md (tracked by git — remember to commit it)

$ carrot-handoff status
task:     Upgrade omniauth-facebook
file:     /home/zarmeza/Developer/my-project/.carrot.md
sections: 1/5 written

$ carrot-handoff load
## Task

Upgrade omniauth-facebook

## State

- Branch: `main`
- HEAD: `4f18f26`
- Worktree: clean
...
```

| Command | Does |
|---|---|
| `carrot-handoff init [TASK]` | Set a repo up: create the note, wire the agent instructions, stage both. |
| `carrot-handoff save [TASK]` | Write or update the note. Preserves sections you already wrote. |
| `carrot-handoff load` | Print the note. |
| `carrot-handoff status` | Task summary plus how many of the five human sections are filled. `State` is machine-derived and not counted. |
| `carrot-handoff clear` | Delete the note. |
| `carrot-handoff path` | Print the note's absolute path. |

Aliases: `new` for `save`, `setup` for `init`, `show`/`cat` for `load`, `st` for
`status`, `rm` for `clear`.

## `init`

`save` writes the note; `init` sets up the repository so a handoff can happen at
all. It does three things:

1. Writes `.carrot.md` if there is not one already.
2. Drops the instructions below into `AGENTS.md`, so some agent knows to read
   the note. Nothing discovers a file on its own.
3. `git add`s both and prints the commit line, because an uncommitted note does
   not survive anything.

**`init` never overwrites an existing note.** `Tried and failed` is the only
record of what was tried, and there is no second copy of it anywhere — so a
reworded `Task` in `init` is applied only when the note is actually being
created. Re-run it as often as you like; it is idempotent, and an existing
block is replaced in place rather than stacked a second time.

Point it at a different instruction file with `--file`, repeatable:

```console
$ carrot-handoff init --file AGENTS.md --file CLAUDE.md
```

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

Run `carrot-handoff init`. It writes the note, adds this block to `AGENTS.md`
between markers, and stages both:

```markdown
<!-- block:begin -->
<!-- carrot-handoff:begin -->
## Handoff notes

This repository uses carrot-handoff to carry a task between agent tools.
The note is `.carrot.md`, committed to this repository.

Before starting work here, run `carrot-handoff load`. If a note exists it
describes work already in progress: read it, follow its `Next action`, and
do not re-derive what its `Decisions` section already settled.

Before you finish, run `carrot-handoff save "<one-line task>"` and then
fill in `Tried and failed` and `Decisions` by hand. The tool can record the
git state; it cannot know what you tried.

Two things to leave alone. `State` is machine-derived and regenerates on
every save, so edits to it are lost. And do not add a `##` heading of your
own: only the six canonical headings round-trip in place, so dated or
thematic context belongs under a `###` inside an existing section.

Commit the note. An uncommitted note does not survive a context reset.
<!-- carrot-handoff:end -->
<!-- block:end -->
```

The markers are what make re-running `init` safe, and they let a later version
of this block replace an earlier one in place. Everything outside them is left
alone — the instruction file belongs to the project, not to this tool.

The `block:` markers are for this file, not for a wired `AGENTS.md`. The copy
above is generated from `Wiring::BLOCK` by `rake docs:sync`, and a spec asserts
the two match, so edit the constant and run the task rather than editing this
copy.

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
$ bundle exec rspec       # run the suite; it reports its own example count
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
`CarrotHandoff::Git`, so the shell-outs are actually exercised. `init` is no
exception: its specs write and re-write real instruction files and read the
staging area back with `git diff --cached`.

CI runs three jobs on every push: **Specs**, **RuboCop**, and a **CLI smoke
test** that drives `bin/carrot-handoff` in a throwaway repo — `help`, an
`init` round trip asserted idempotent by checksum, a save/status/load round
trip, and a check that it exits non-zero outside a repository. Specs passing on
one laptop is not evidence for anyone else, and a portfolio project needs the
evidence to be reproducible.

## Layout

```text
bin/carrot-handoff             entry point
lib/carrot_handoff.rb          FILENAME, Repo (path lookups), Error
lib/carrot_handoff/git.rb      git binary wrapper; reads return nil, never raise
lib/carrot_handoff/record.rb   markdown in, sections out
lib/carrot_handoff/store.rb    file IO
lib/carrot_handoff/template.rb note rendering, git state assembly
lib/carrot_handoff/wiring.rb   the AGENTS.md block, and its markers
lib/carrot_handoff/init.rb     one-time setup: note, wiring, staging
lib/carrot_handoff/cli.rb      argument dispatch
spec/                          specs
.carrot.md                     this repo's own handoff note
AGENTS.md                      conventions for agents working here
```
