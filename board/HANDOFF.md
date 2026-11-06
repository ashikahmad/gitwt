# gitwt handoff

Written 2026-11-06, updated after PR #10 was merged, so the next session can carry on without the conversation. The board ([`kanban.md`](kanban.md), [read-only view](https://ashikahmad.github.io/Kanban.md/app/?board=https://github.com/ashikahmad/gitwt/blob/dev/board/kanban.md)) has the detail for every task; this file is the map.

## Where things stand

| | |
|---|---|
| Released | **v0.2.0** on `main` (`0e13fd4`, PR #6), tag `v0.2.0`, [GitHub release](https://github.com/ashikahmad/gitwt/releases/tag/v0.2.0) |
| Site | https://ashikahmad.github.io/gitwt/ deployed from `main` by `.github/workflows/pages.yml` (first run succeeded) |
| `dev` | `main` plus: README and `gitwt help` link the site; board updates. These reach `main` with the next release |
| Open PRs | none |
| Tests | 213, all pass on bash 5.2 (`./run_tests.sh`, ~4 min) |
| Issues | [#11](https://github.com/ashikahmad/gitwt/issues/11) bash tab-completion, a `vote` issue (TASK-037) |

## Still to check from v0.2.0 (needs a browser outside the cloud session)

- The live site renders: `/` and `/docs/`, and `/docs/#whats-supported` (the link in the bash 3.2 messages) lands on that section. A local build has the anchor.
- The guide's links to Homebrew's bash formula and Apple's "Use zsh as the default shell on your Mac" page work.

Then move TASK-034 and TASK-036 to Done. Verified already: the release and tag point at `0e13fd4`; the real one-liner installed files identical to the tag, and zsh had gitwt and completion.

## Notes for the next release

- Release by PR `dev` → `main`, then tag `vX.Y.Z` on `main` at once (the one-liner downloads from the tag). Bump `GITWT_VERSION` in both `gitwt.sh` and `install.sh` first (a test keeps them equal), and the by-hand URLs in `docs/usage.md` (a test checks them).
- **Cloud sessions can't push tags or create releases** (tag pushes are cut off; the GitHub tools only read releases). The owner publishes the release on GitHub with a new tag on `main`, which creates the tag; a draft doesn't create it.

## What's been done (merged into `dev`)

| PR | What | Tasks |
|---|---|---|
| #1 | `--from` with no value no longer hangs | 005 |
| #2 | New worktree setup: `.worktreeinclude` copies ignored files; setup script (`.gitwt/post-create` or `gitwt.postCreate`) runs once approved | 004 |
| #3 | `gitwt.path` template for where worktrees go; clearer path clashes | 023, 018 |
| #4 | Usage guide `docs/usage.md`; README trimmed | 024, 017 |
| #5 | `remove` refuses to lose uncommitted work or edited/worktree-only listed files; `--force`; cd handling | 001, 002, 012 |
| #7 | `gitwt move` / `mv` | 003 |
| #8 | Website: hand-written landing page + Just the Docs guide, Catppuccin Latte/Frappé, green accent; deploys from `main` | 034 (in review) |
| #9 | `gitwt ls` instant by default (3 git commands), `-l` adds CHANGES, `-s` bare list | 033, 019 |
| #6 | Release v0.2.0 (`dev` → `main`) | |
| #10 | One-line install from the version tag; installer rewritten (two independent reviews, tested on macOS 26 with `/bin/bash` 3.2); bash 3.2 not-supported check in `gitwt`; "What's supported" and Uninstall in the guide | 036 (in review), 008, 014, 022 |

Also on the board: 8 archived `#history` tasks (TASK-025–032) recording what existed before the board.

## Decisions already made

Don't reopen these without a reason:

- **Workflow:** feature branch → PR into `dev` → independent review by a separate agent given the code and spec, not conclusions → fix findings with tests that fail on the reviewed code → merge. Release by PR `dev` → `main`. Board-only and small docs changes go straight to `dev`. The owner asks for PRs and merges explicitly.
- **Shells:** zsh and bash 4+ (tested: zsh 5.9, bash 5.2). bash 3.2 isn't officially supported (it lacks associative arrays, which `ls` uses). git 2.18+.
- **`remove`:** no prompts, never writes to the main repo; refuses and prints `diff`/`cp` commands. Only files listed in the main repo's `.worktreeinclude` are checked; other ignored files are named in one line.
- **`move`:** no `--force` (unlock locked worktrees explicitly); one generic note after every move about tools that saved the old full path, rather than detecting tools.
- **Setup script:** `gitwt.postCreate` (git config) overrides `.gitwt/post-create`; empty disables; approval by content hash in `gitwt.postCreateApproved`.
- **`ls`:** default reads only git's records; anything that reads every file goes behind `-l`; `-s` stays for scripts and the planned picker.
- **Site:** builds from `main` so it documents the released version; the guide is copied from `docs/usage.md` at build time (one source); the landing page is hand-written, so update it with the README when features change. Light-mode accent is `#307820` (Catppuccin Latte green darkened for 4.5:1 contrast); dark uses Frappé's `#a6d189`.
- **Install:** the one-liner downloads from the version tag, not `main`. Homebrew left for later.
- **bash 3.2:** not supported. `gitwt` checks once at the top and stops every command (help and version too) with two lines: the fact and the site link. Neither script tells people to change shells; the guide lists options (use zsh or a newer bash alongside, without changing the default). The installer checks the login shell (`$SHELL`), not the bash running it (on a Mac that's always 3.2), asks on `/dev/tty` before changing anything (default no), and on yes also sets up zsh if installed.
- **Demand:** "not yet" features get a GitHub issue with the `vote` label; people 👍 it, and the guide/site link to it where the gap shows. Bash completion is #11.

## Backlog worth picking up next

- **TASK-038:** an uninstaller (`install.sh --uninstall`); the guide has by-hand steps meanwhile. Edits shell config, so its own PR and review.
- **TASK-037:** bash tab-completion, only if #11 gets votes.

- **TASK-035:** `gitwt sw` with no branch opens a picker (fzf if installed, numbered menu otherwise), using `ls -s`'s single-call list.
- **TASK-015:** run the suite under zsh too and add CI (the suite is bash-only; zsh is checked by hand).
- **TASK-006, 009, 010, 011:** `new`'s remote/`--fetch` edge cases. **TASK-007:** reject unknown flags. **TASK-013:** `remove --branch` failure reporting. **TASK-020:** detached worktrees in `switch`/`remove`. **TASK-021:** clear error outside a repo. **TASK-016:** tests from a fresh clone.

## Working notes and gotchas

- **Tests:** `git submodule update --init` first, then `./run_tests.sh` (bats, ~4 min). Check zsh by hand: `zsh -f -c 'source ./gitwt.sh; …'`, and interactively via `script -qec "zsh -f -i" /dev/null`. `test/install.bats` uses a fake `curl` and runs from an unrelated folder; the read-only-file test skips as root, so check that case as a non-root user (`runuser -u nobody …`).
- **zsh traps found this session:** re-declaring `local x` inside a loop prints `x=…`; a process substitution `< <(…)` doesn't get Ctrl-C in interactive zsh (use `$(…)`); pattern-matching against one long string is slow (use associative arrays); unquoted variables don't word-split.
- **Speed:** every `$(func)` is a subshell; in loops, have helpers set variables instead.
- **Counting characters:** mawk counts bytes; measure widths in bash with a UTF-8 locale.
- **Site preview:** in a copy of `site/`, run `./prepare.sh <repo> .`, then `bundle install` (set `BUNDLE_PATH` to a scratch folder) and `bundle exec jekyll build -d <out>`; serve `<out>`'s parent and open `/gitwt/`. The Pages host is blocked in the sandbox; screenshots via Playwright's Chromium.
- **Board:** Kanban.md format v3 (`ashikahmad/Kanban.md`, public; clone it to check parsing with its `core/board.js`). Finished tasks get `**Finished**: <date>`; history lives in `archive.md`. The read-only viewer shows `dev`; raw GitHub files can lag a few minutes after a push.
- **Commits:** end with the `Co-Authored-By` and `Claude-Session` trailers; PR bodies follow the earlier PRs' layout (Summary, Evidence, Merge Danger) and end with the Claude Code line.
