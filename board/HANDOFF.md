# gitwt handoff

Written 2026-11-06 at the end of a long working session, so the next session can carry on without the conversation. The board ([`kanban.md`](kanban.md), [read-only view](https://ashikahmad.github.io/Kanban.md/app/?board=https://github.com/ashikahmad/gitwt/blob/dev/board/kanban.md)) has the detail for every task; this file is the map.

## Where things stand

| | |
|---|---|
| `main` | `f4d1f40`, unchanged since the session started; 40 commits behind `dev`. Tag `v0.1.0` exists |
| `dev` | `e67c001`; has PRs #1–#9 merged, plus board and docs commits |
| Open PR | [#10](https://github.com/ashikahmad/gitwt/pull/10) `feat/one-line-install` → `dev`, head `a6d4c71`; **reviewed, findings below not fixed yet** |
| Version | `0.1.0` on `dev`; PR #10 bumps it to `0.2.0` |
| Tests | 155 on `dev`, 173 on PR #10's branch; all pass on bash 5.2 |
| Board on `dev` | 12 done, 14 backlog, 1 in review (TASK-034, the website, waiting for release). On PR #10's branch, TASK-008/014/022/036 are in review |

## Next steps, in order

1. **Fix PR #10's review findings** (below), each with a test that fails on the reviewed code, then push to the same branch and update the PR description. Consider a fresh independent review afterwards.
2. **Merge PR #10 into `dev`.** Move TASK-008, TASK-014, TASK-022 and TASK-036 to Done (TASK-036 keeps its last subtask open until the tag exists).
3. **Release** (see the checklist below).

### PR #10 review findings to fix

Reproduced by an independent review (fake `curl`, throwaway `HOME`):

1. **Bug, install.sh:135-138:** a zsh user with a `~/.bashrc` but no `~/.zshrc` (Ubuntu's default home; macOS with an old `.bashrc`) gets only `.bashrc` wired up, and gitwt never loads in zsh, though the installer says it's installed. `$SHELL` is only consulted when neither file exists. **Fix:** when `$SHELL` is zsh or bash, always wire up that shell, creating its rc file if missing; also wire up other rc files that exist.
2. **install.sh:140:** a `.zshrc` the installer creates has no `compinit`, so `_gitwt`'s new `compdef` guard silently skips completion: the main macOS case. The guide says zsh gets tab-completion. **Fix:** when creating `.zshrc`, write `autoload -Uz compinit && compinit` before the gitwt lines.
3. **install.sh:94-104:** if `~/.config/gitwt/gitwt.sh` is a symlink to somewhere else (an old clone, a dotfile manager), a piped install replaces the link with a regular file. **Fix:** decide: probably leave a symlink alone and say how to update it (or follow it and refuse); test both "same file" and "points elsewhere".
4. **install.sh:120 `has_source_line`:** matches too much and too little. False "already loads": `source ~/work/othertool/gitwt.sh` (a different clone stays in use while the message says 0.2.0 is installed), `echo "run: source ~/.config/gitwt/gitwt.sh"`, `gitwtXsh` (unescaped `.`). False "missing": `…/gitwt.sh#x`, `PS1="#> "; source …`, `…gitwt.sh&&true`. **Fix:** match the installed path specifically (`.config/gitwt/gitwt.sh` via `$HOME`, `${HOME}`, `~`, an absolute home path, or `$XDG_CONFIG_HOME`), escape the dot, and allow `&`/`|`/`#` after it; keep the cases the review found working (`[[ -f … ]] && . …`, `${HOME}`, trailing comments, commented-out lines, tab indent, inside `if … fi`).
5. **Truncated download:** the script body isn't wrapped in a function, so `curl … | bash` cut short can exit 0 having done half the work (e.g. files installed, no rc line). **Fix:** wrap everything in `main() { … }` and call `main "$@"` on the last line.
6. Nits: two installs at once can add the line twice; `curl … | sh` fails with `set: Illegal option -o pipefail` (say "use bash" or re-exec); running a symlink to install.sh downloads instead of using the clone; the final `source $ZSHRC` hint isn't quoted (breaks with spaces in `HOME`); sourcing install.sh leaves `errexit`/`nounset` on.
7. Docs: the by-hand steps download from `main` while the one-liner uses the tag, and `cd` the user into `~/.config/gitwt`; the "read it first" `bash install.sh` installs local files if run in a folder that holds `gitwt.sh` and `_gitwt` (download to a temp folder instead).

Suspected, not reproduced: `ZDOTDIR` set only inside zsh isn't seen by the bash running the installer; macOS users whose old install wrote to `.zprofile` would also get lines in a new `.zshrc` (loads twice) — consider recognising `.zprofile`/`.bash_profile` lines too.

### Release checklist

1. **Owner:** Settings → Pages → Source: **GitHub Actions** (needed for the site workflow).
2. Open a release PR `dev` → `main` with release notes. Call out: `gitwt ls` no longer shows CHANGES without `-l`; `gitwt remove` refuses when it would lose uncommitted work or an edited listed file (`--force` overrides); bash 3.2 isn't officially supported; the one-line install.
3. After merging, **tag `v0.2.0` on `main` and push the tag.** Until the tag exists, the one-liner downloads 404 and installs nothing. Consider creating a GitHub release from it.
4. Check: the Pages workflow run, `https://ashikahmad.github.io/gitwt/` and `/docs/`, and the one-liner in a throwaway `HOME` (`HOME=$(mktemp -d) SHELL=/bin/zsh bash -c 'curl -fsSL …/main/install.sh | bash'`).
5. Then (TASK-034's last subtasks): link the site from the README and `gitwt help` (the help text currently links to `docs/usage.md` on `main` on GitHub), move TASK-034 and TASK-036 to Done.
6. Optionally delete the merged feature branches on GitHub (all `fix/*`, `feat/*` and `docs/*` except any still open).

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

## Backlog worth picking up next

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
