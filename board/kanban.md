# Kanban Board

<!-- Config: Last Task ID: 32 -->
<!-- Format: v3 -->

## ⚙️ Configuration

**Columns**: 📥 Backlog (backlog) | 📝 To Do (todo) | 🚀 In Progress (in-progress) | 👀 In Review (in-review) | ✅ Done (done)

**Categories**: CLI, Shell Integration, Install, Tests, Documentation

**Users**: @ashikahmad (Ashik Uddin Ahmad)

**Priorities**: 🔴 Critical | 🟠 High | 🟡 Medium | 🟢 Low

**Tags**: #bug #feature #refactor #docs #test #history

---

## Tasks

### TASK-001 | Protect ignored files when removing a worktree
**Status**: done  
**Priority**: High  
**Category**: CLI  
**Created**: 2026-11-05  
**Started**: 2026-11-06  
**Finished**: 2026-11-06  
**Tags**: #bug #feature  

`gitwt remove` relies on `git worktree remove`, which refuses modified, staged and untracked files but deletes ignored files without warning. A test worktree with an ignored `.env` was removed with exit 0 and the file was gone for good. gitwt also has no `--force` flag of its own, so forcing means dropping to raw git. Since TASK-004, gitwt copies `.env` and similar files into every new worktree, which makes editing them there, and losing the edits on removal, more likely.

**Subtasks**:
- [x] Check the files listed in the main repo's `.worktreeinclude`, using the helper from TASK-004
- [x] Stay quiet when a listed file is an unchanged copy of the main repo's
- [x] Refuse when a listed file was changed in the worktree, naming it and showing how to compare it
- [x] Refuse when a listed file exists only in the worktree, showing the command to copy it out, with a warning if it isn't ignored in the main repo
- [x] Mention other ignored files in one line, without asking; without a `.worktreeinclude`, suggest adding one
- [x] Add `gitwt remove --force`, which skips these checks and discards uncommitted work
- [x] Refuse the main worktree with a clear message (TASK-002)
- [x] Make the failed-removal tip accurate about `--force` (TASK-002)
- [x] Only leave the worktree once removal goes ahead, and return you where you were if it fails (TASK-012)
- [x] Compare whole, physical paths when deciding whether you're inside the worktree (TASK-012)
- [x] Add tests for each case, and update the usage guide and `gitwt help`

**Notes**:
**Design**: `.worktreeinclude` already says which ignored files matter, so the same list decides what's copied into a new worktree and what's checked before deleting one. Being listed doesn't make a file at risk: an unchanged copy loses nothing, because the main repo still has it. gitwt compares only with the main repo, not other worktrees. There are no prompts: a file at risk makes `remove` refuse and say what to do, so it behaves the same with or without a terminal, and gitwt never writes into the main repo. Unlisted ignored files, such as `node_modules/` or `dist/`, are mentioned in one line but never block removal; asking about them would happen on almost every removal and train people to say yes.

**Plan**: revised 2026-11-06. TASK-004 came first and is done. This task also takes in TASK-002 and TASK-012, which change the same lines of `_gitwt_remove`. The data-loss risk stays until this task is done.

**Result**: `gitwt remove` now refuses when it would lose a file listed in the main repo's `.worktreeinclude`: one changed in the worktree gets a `diff` command, one that exists only there gets a `cp` command, with a warning if the main repo doesn't ignore it. Unchanged copies are removed quietly, and other ignored files are named in one line. It also refuses uncommitted work up front, before moving you anywhere, and refuses the main repo's own branch. `--force` skips the checks. You're moved out of the worktree only once removal goes ahead, and returned if git still refuses (for example, a locked worktree). No prompts, so scripts and terminals behave the same. Added 14 tests; 12 fail against the old code, and the other 2 guard cases the old code already handled. Full suite 101/101 on bash 5.2, and the main cases were run by hand under zsh.

**Modified files**:
- gitwt.sh
- test/remove.bats
- docs/usage.md
- README.md

### TASK-002 | Make the failed-removal tip accurate about --force
**Status**: done  
**Priority**: Medium  
**Category**: CLI  
**Created**: 2026-11-05  
**Started**: 2026-11-06  
**Finished**: 2026-11-06  
**Tags**: #bug  

When removal fails, gitwt.sh:244 suggests `git worktree remove --force` whatever the cause, and does not say that it permanently discards the uncommitted work git was protecting. The main worktree gets the same tip, although `--force` cannot remove it.

**Subtasks**:
- [x] Say that `--force` discards uncommitted work
- [x] Only suggest `--force` when it applies

**Notes**:
**Plan**: done as part of TASK-001, which adds `gitwt remove --force` and rewrites this tip.

### TASK-003 | Add gitwt move to relocate or rename a worktree
**Status**: in-review  
**Priority**: Medium  
**Category**: CLI  
**Created**: 2026-11-05  
**Started**: 2026-11-06  
**Tags**: #feature  

gitwt has no move or rename command. `git branch -m` works and `gitwt sw` still finds the branch, but the folder keeps the old name (`feature/new` stays in `feature-old`). `git worktree move` works and gitwt picks up the new path, but it has to be run by hand. Git cannot move the main worktree or one containing submodules.

**Subtasks**:
- [x] Decide the interface: `gitwt move <branch> [<new-path>]`, alias `mv`
- [x] Keep the folder name in step with a renamed branch
- [x] Give a clear error for the main worktree and submodule cases
- [x] Explain the other cases git refuses: destination exists, locked worktree, another drive
- [x] Create missing parent folders, since git doesn't
- [x] Move your shell to the new path if you're inside the worktree
- [x] Print one generic note after moving about things that saved the old full path
- [x] Add tests, zsh completion and docs

**Notes**:
**Findings** (git 2.43, 2026-11-06): `git worktree move` renames the folder in one step, so staged, modified, untracked and ignored files, `.env` included, all arrive as they were, and `git status` reads the same afterwards. It needs no `--force` for a dirty worktree. A failed move changes nothing: moving to another filesystem fails with "Invalid cross-device link" and leaves the worktree in place and registered. git also refuses a locked worktree (unless `-f -f`), the main worktree, worktrees with submodules, an existing destination, and a destination whose parent folder doesn't exist.

**Design**: nothing is deleted, so the `.worktreeinclude` checks from TASK-001 aren't needed, and the setup script isn't rerun. What can break is anything that saved the worktree's full path: in testing, an absolute symlink broke and a relative one didn't; virtualenvs, some build caches and tool settings do the same, and running programs keep the old path. Rather than detect specific tools, which would miss the rest and suggest the list is complete, gitwt prints one generic note after every move:

```text
Files are unchanged. Anything that saved the old full path may need recreating or
restarting: virtualenvs, build caches, absolute symlinks, or programs still running there.
```

The usage guide explains it in more detail.

**Result**: `gitwt move <branch> [<new-path>]` (alias `mv`). Without a path it moves the worktree to where `gitwt.path` puts the branch, so `git branch -m` followed by `gitwt move <new-name>` keeps the folder in step. A given path that's an existing folder or ends in `/` means "into it", like `mv`. Missing parent folders are created, and removed again if the move fails. If you're inside, you move with it to the same subfolder. Refused up front with nothing changed: the main repo, an existing destination (naming the branch or repo that has it, for the default path), a destination inside the worktree, a locked worktree (with the unlock command), and another drive. Submodules get git's refusal plus a tip. The generic note prints after every move. No `--force`: a lock is deliberate, so unlocking explicitly is clearer than overriding it. Added 27 tests; full suite 128/128 on bash 5.2, and renaming plus moving from inside were run by hand under zsh, along with completion.

**Modified files**:
- gitwt.sh
- _gitwt
- test/move.bats
- docs/usage.md
- README.md

**Review**: an independent review of PR #7 found three bugs, all fixed with tests: folders left behind when creating the parent folders failed partway; a false "already at" under zsh for a worktree path containing a backslash (`_gitwt_find_path` printed with zsh's `echo`); and a locked worktree with a backslash in its path not detected (`awk -v`). It also found message and docs gaps, now fixed: "into itself" through a symlink is refused by gitwt, a symlinked folder is documented as the destination itself, the different-drive and submodule tips print a `git worktree add` command instead of suggesting `gitwt new`, the current location written out says "already at", a file on the path gets a clear error, and completion no longer offers the main repo's branch or folders past the second argument.

### TASK-004 | Automate new worktree setup with .worktreeinclude and a post-create hook
**Status**: done  
**Priority**: Medium  
**Category**: CLI  
**Created**: 2026-11-05  
**Started**: 2026-11-05  
**Finished**: 2026-11-06  
**Tags**: #feature  

gitwt has no setup step, so ignored files and project setup must be redone by hand in every new worktree. Git's `post-checkout` hook does fire on `gitwt new`, but it also fires on ordinary checkouts, and hooks in `.git/hooks` are not versioned or shared. Similar tools combine a list of ignored files to copy with post-create commands; `.worktreeinclude` is used by Claude Code, wt-cli and PostHog Code.

**Subtasks**:
- [x] Put reading `.worktreeinclude` in a helper that TASK-001 can reuse
- [x] Copy files listed in `.worktreeinclude` (gitignore syntax) into new worktrees
- [x] Run an optional post-create script from the repo
- [x] Require approval or opt-in before running a repo-supplied script
- [x] Add tests and docs

**Notes**:
**Result**: `gitwt new` copies ignored files listed in the main repo's `.worktreeinclude` into the new worktree without overwriting anything, then runs `.gitwt/post-create` inside it. The script runs only once that exact version is approved; the approval is stored as a hash in `gitwt.postCreateApproved` in the repo's local git config. Without a terminal, an unapproved script is skipped with a note. `git config gitwt.postCreate <path>` (repo or global) runs that script instead, so a script people also run by hand, like `scripts/setup.sh`, can be used; only one script runs, an empty value turns setup off, and a configured script that is missing, not executable or outside the repo warns and returns 1 without falling back. A failing script or a file that cannot be copied gives a warning, keeps the worktree, still moves you into it, and returns 1. Added 22 tests; full suite 42/42 under bash 3.2 before the copy-failure fix and `gitwt.postCreate`, and 51/51 under bash 5.2 after them. Copying and the approval prompt were also run by hand under zsh and bash.

**Modified files**:
- gitwt.sh
- README.md
- test/setup.bats

**Plan**: separate work that comes first, followed by TASK-001. The removal check itself belongs to TASK-001, not this task.

**Shared with TASK-001**: the code that reads `.worktreeinclude` is one helper, `_gitwt_included_files <dir>`, because TASK-001 uses the same list to decide which ignored files to protect on removal. Files copied in by this task are the ones it compares with the main repo's copy, so keep the copy step predictable.

### TASK-005 | Fix infinite loop when --from has no value
**Status**: done  
**Priority**: High  
**Category**: CLI  
**Created**: 2026-11-05  
**Started**: 2026-11-05  
**Finished**: 2026-11-06  
**Tags**: #bug  

`gitwt new foo --from` and `gitwt new --from` never finish, because `shift 2` fails without shifting (gitwt.sh:88). bash hangs silently; zsh prints `shift count must be <= $#` repeatedly (36 MB in 5 seconds). `--from=` does not hang.

**Notes**:
**Result**: `--from` with a missing, empty or flag-like value now prints an error and usage and returns 1 before creating anything. `--from=<base>` is normalised into the same check. Added 5 tests; full suite 34/34 under bash, and the error cases were also run by hand under zsh.

**Modified files**:
- gitwt.sh
- test/new.bats

### TASK-006 | Warn when a branch already exists only on the remote
**Status**: backlog  
**Priority**: High  
**Category**: CLI  
**Created**: 2026-11-05  
**Tags**: #bug  

With a fetched `origin/feature/x` and no local branch, `gitwt new feature/x` creates a new branch from the current one, with no upstream and no warning, so the remote work is missing. Raw `git worktree add <path> feature/x` tracks the remote branch instead.

### TASK-007 | Reject unknown flags, extra arguments and unknown commands
**Status**: backlog  
**Priority**: High  
**Category**: CLI  
**Created**: 2026-11-05  
**Tags**: #bug  

Argument parsing lets the last positional win and treats unknown flags as branch names. `gitwt remove a b` removes only b. `gitwt new foo --frm develop` targets `develop` and drops `foo`. `gitwt remove --force a` removes a without forcing or complaining. `gitwt nwe foo` prints help and returns 0 (gitwt.sh:16), so typos in scripts pass silently.

### TASK-008 | Fix install.sh reporting success when nothing was wired up
**Status**: backlog  
**Priority**: High  
**Category**: Install  
**Created**: 2026-11-05  
**Tags**: #bug  

With no `.zshrc`, `.bashrc` or `.zprofile`, install.sh prints `not found — skipping` for each file, then `==> Done!`, returns 0 and says to `source ~/.zshrc`, which does not exist. A new shell cannot find `gitwt`. The Darwin fallback helps only when `.zprofile` already exists, and the `.bash_profile` fallback named in the comment is not implemented.

### TASK-009 | Stop new branches tracking their base after --fetch
**Status**: backlog  
**Priority**: Medium  
**Category**: CLI  
**Created**: 2026-11-05  
**Tags**: #bug  

When `--fetch` branches from the remote-tracking ref (behind case, or diverged choice 1), git sets the new branch's upstream to `origin/<base>`. It prints this, but gitwt adds no explanation. `gitwt list` and `git status` then compare against the base, `git pull` pulls the base's commits, and `git push` fails with an upstream mismatch. The up-to-date, ahead-only and diverged choice 2 cases set no upstream, so behaviour is inconsistent. Tested with default `branch.autoSetupMerge`.

### TASK-010 | Accept remote refs, tags and SHAs in --from
**Status**: backlog  
**Priority**: Medium  
**Category**: CLI  
**Created**: 2026-11-05  
**Tags**: #feature  

`--from` accepts only local branches (gitwt.sh:133): `origin/main`, a tag and a SHA are all rejected. `gitwt new x --from develop --fetch` fails before fetching when develop exists only on the remote, so the "does it all in one shot" claim at README.md:22 holds only when local develop exists.

### TASK-011 | Use the configured upstream name in --fetch
**Status**: backlog  
**Priority**: Medium  
**Category**: CLI  
**Created**: 2026-11-05  
**Tags**: #bug  

`--fetch` assumes the upstream has the same name as the local base (gitwt.sh:149-152). When `dev` tracks `origin/develop`, it fails with `couldn't find remote ref dev`. If an `origin/dev` also exists, it branches from that and ignores the real upstream, returning 0.

### TASK-012 | Fix current-directory handling in gitwt remove
**Status**: done  
**Priority**: Medium  
**Category**: CLI  
**Created**: 2026-11-05  
**Started**: 2026-11-06  
**Finished**: 2026-11-06  
**Tags**: #bug  

Three related problems around gitwt.sh:237-243. The check is a plain string prefix, so from `feature-x-2`, removing `feature/x` wrongly moves the shell to the main repo (the right worktree is still removed). The cd happens before removal, so a failed removal still leaves you in the main repo. Entering a worktree through a symlink defeats the check, so it is deleted around you and the shell is left in a missing directory; this does not happen if you got there via `gitwt new`.

**Subtasks**:
- [x] Compare whole path components
- [x] Only leave the worktree once removal can go ahead
- [x] Compare physical paths

**Notes**:
**Plan**: done as part of TASK-001, which adds new ways for removal to be refused; with the cd still happening first, each refusal would leave you in the main repo.

### TASK-013 | Report gitwt remove --branch failures correctly
**Status**: backlog  
**Priority**: Medium  
**Category**: CLI  
**Created**: 2026-11-05  
**Tags**: #bug  

When the branch delete fails, the function still returns 0 and always blames unmerged commits (gitwt.sh:250-254). A branch used by another worktree and a stale ref lock both produce the wrong tip with status 0. test/remove.bats:37 checks the tip but not the status.

### TASK-014 | Stop zsh startup error when compinit has not run
**Status**: backlog  
**Priority**: Medium  
**Category**: Shell Integration  
**Created**: 2026-11-05  
**Tags**: #bug  

Without compinit, sourcing `_gitwt` fails with `command not found: compdef` (_gitwt:96). install.sh adds the source line without checking, so a `.zshrc` without compinit prints the error at every shell start. `gitwt` itself still loads, and a `.zshrc` that runs compinit earlier is unaffected.

### TASK-015 | Test under zsh, cover --fetch and add CI
**Status**: backlog  
**Priority**: Medium  
**Category**: Tests  
**Created**: 2026-11-05  
**Tags**: #test  

The suite runs only under bash (test/run_gitwt.sh), although zsh is the primary shell. No test mentions zsh or `--fetch`, and the repo has no CI config. A manual zsh smoke test of new, sw, list and remove found no zsh-only breakage, but nothing guards that. All 29 existing tests pass with submodules initialised.

### TASK-016 | Make the test suite easy to run from a fresh clone
**Status**: backlog  
**Priority**: Medium  
**Category**: Tests  
**Created**: 2026-11-05  
**Tags**: #test #docs  

Without `--recurse-submodules`, `test/libs/*` is empty and run_tests.sh fails with `No such file or directory`. The README never mentions tests, submodules or bats. run_tests.sh also uses a relative `test/` path, so it fails when run from another directory.

### TASK-017 | Correct out-of-date README claims
**Status**: done  
**Priority**: Medium  
**Category**: Documentation  
**Created**: 2026-11-05  
**Started**: 2026-11-06  
**Finished**: 2026-11-06  
**Tags**: #docs  

**Subtasks**:
- [x] README.md:41: replace the `your-username` clone URL with `ashikahmad`
- [x] README.md:207: change "Git 2.5+" to 2.18+, since `git worktree list --porcelain` needs 2.7 and `git worktree remove` needs 2.17
- [x] README.md:131: show `✓ clean` instead of `clean`
- [x] README.md:31: describe all four `list` columns, not just branch and path
- [x] README.md:19: reword "no sibling folders", since `../worktrees` is one sibling folder; "outside your repo" is accurate

**Notes**:
**Result**: done as part of TASK-024's README rewrite. The minimum is 2.18, not 2.17: `gitwt.path` reads its value with `git config --type=path`, which arrived in git 2.18. The `list` example and column descriptions moved to the usage guide.

**Modified files**:
- README.md
- docs/usage.md

### TASK-018 | Explain worktree path collisions
**Status**: done  
**Priority**: Low  
**Category**: CLI  
**Created**: 2026-11-05  
**Started**: 2026-11-05  
**Finished**: 2026-11-06  
**Tags**: #bug  

`feature/a-b`, `feature-a/b`, `feature/a/b` and `feature-a-b` can coexist in git but all map to the slug `feature-a-b`. The second `gitwt new` fails with `worktree path already exists` and a `gitwt list` tip, without naming the collision or the branch that owns the path.

**Notes**:
**Result**: the error now says what is using the folder: a branch, a detached worktree, a checkout of another repo, or something that isn't a worktree. Each case gets its own tip. Done together with TASK-023, which makes these clashes easier to hit.

**Modified files**:
- gitwt.sh
- README.md
- test/path_config.bats

### TASK-019 | Fix gitwt list alignment and bare repo display
**Status**: backlog  
**Priority**: Low  
**Category**: CLI  
**Created**: 2026-11-05  
**Tags**: #bug  

Under bash 3.2, printf pads by bytes, so `✓`, `·` and `─` misalign rows (PATH starts at column 93-99; always 99 under zsh in a UTF-8 locale, while `LC_ALL=C` zsh misaligns too). Both shells shift when CHANGES exceeds 30 characters. A bare repo's entry shows as `(detached:)` with `✓ clean`. Newer bash versions were not tested.

### TASK-020 | Let switch and remove target detached worktrees
**Status**: backlog  
**Priority**: Low  
**Category**: CLI  
**Created**: 2026-11-05  
**Tags**: #feature  

`gitwt list` shows `(detached:8054df3)`, but `switch` and `remove` look up by branch only. The label, short SHA, full SHA and path all give `no worktree found for branch`.

### TASK-021 | Give a clear error outside a git repo
**Status**: backlog  
**Priority**: Low  
**Category**: CLI  
**Created**: 2026-11-05  
**Tags**: #bug  

The check at gitwt.sh:33 never fires because the pipeline's status is awk's. Outside a repo, git's `not a git repository` prints first, then gitwt adds a misleading line: `could not determine current branch (are you in detached HEAD state?)`, or `base branch 'x' does not exist locally` with `--from x`. `gitwt list` already handles this correctly.

### TASK-022 | Make install.sh handle earlier installs correctly
**Status**: backlog  
**Priority**: Medium  
**Category**: Install  
**Created**: 2026-11-05  
**Tags**: #bug  

Reinstalling over the installer's own earlier install works: files are updated and no lines are duplicated. Other kinds of earlier install go wrong. Tested in throwaway home directories.

Run from a clone in `~/.config/gitwt`, or with installed files symlinked to a repo, `cp` fails with `are identical (not copied)`. `set -e` then stops the script at install.sh:50 with exit 1, before any shell config lines are added. Read-only installed files stop it at the same point with `Permission denied`.

`append_if_missing` searches for one exact line (install.sh:28). `source "$HOME/.config/gitwt/gitwt.sh"` and `source ~/.config/gitwt/gitwt.sh`, the forms the README and `gitwt help` tell people to use, are not recognised, so a second set of source lines is added and gitwt loads twice. A commented-out line is treated as installed, so gitwt stays disabled while the installer reports `Already present` and `Done!`.

**Subtasks**:
- [ ] Skip the copy when source and destination are the same file
- [ ] Still wire up shell config when the copy is skipped
- [ ] Recognise any active line that sources gitwt, whatever form its path takes
- [ ] Ignore commented-out lines when checking
- [ ] Report clearly what was updated, added or left alone
- [ ] Add tests for these reinstall cases

**Notes**:
**Related**: TASK-008 covers a home with no shell config files. TASK-014 covers the `compdef` error from the source line.

**Also noted, not in scope yet**: the installer's reinstall output shows no versions, and every version reports `0.1.0`. Source lines use an absolute home path rather than `$HOME`. There is no uninstall.

### TASK-023 | Let users configure the worktree path
**Status**: done  
**Priority**: Medium  
**Category**: CLI  
**Created**: 2026-11-05  
**Started**: 2026-11-05  
**Finished**: 2026-11-06  
**Tags**: #feature  

New worktrees always went to `../worktrees/<repo>/<slug>`. The `gitwt.path` git config now takes a template with `{repo}`, `{slug}` and `{branch}`, and the old location stays the default.

**Subtasks**:
- [x] Resolve the template in `_gitwt_generate_path`
- [x] Reject templates with no `{slug}` or `{branch}`, unknown placeholders, and shell variables such as `$HOME`
- [x] Note when a worktree inside the repo isn't ignored
- [x] Keep the developer's own git config out of the tests
- [x] Add tests and update the README and `gitwt help`

**Notes**:
**Design**: git config rather than a dotfile or env var. It needs no parser, gives repo-over-global precedence and `includeIf`, and a cloned repo can't set it, so a repo can't choose where worktrees go on someone's machine.

**Result**: `gitwt new` builds the path from `gitwt.path` and rejects templates it can't use before creating anything. `switch`, `remove` and `list` needed no changes, because they read registered paths from git.

**Modified files**:
- gitwt.sh
- README.md
- test/path_config.bats
- test/test_helper.bash

**Related**: TASK-003 covers moving existing worktrees. TASK-018 explains path collisions, which custom templates make easier to hit.

### TASK-024 | Write a usage guide and trim the README
**Status**: done  
**Priority**: Medium  
**Category**: Documentation  
**Created**: 2026-11-06  
**Started**: 2026-11-06  
**Finished**: 2026-11-06  
**Tags**: #docs  

Each feature PR documents itself in the README, so after TASK-004 and TASK-023 the README has grown one section at a time. Nothing covers how features combine, and the `gitwt.*` settings are documented in different places. A separate, to-the-point guide keeps the README short.

**Subtasks**:
- [x] Write `docs/usage.md`, one section per command and feature: what it does, exact commands, and what happens on failure
- [x] Add one reference table of all `gitwt.*` settings (`gitwt.path`, `gitwt.postCreate`, `gitwt.postCreateApproved`): purpose, repo or global, default
- [x] Explain how custom paths, `.worktreeinclude` and the setup script work together, including worktrees inside the repo and symlinked paths (`GITWT_WORKTREE` holds the symlink path)
- [x] Add troubleshooting built from the actual messages, such as "not approved", "doesn't exist in the new worktree" and "could not copy"
- [x] Trim the README to an overview and quick start that link to the guide
- [x] Check that `gitwt help` matches the guide

**Notes**:
**Plan**: start after PR #3 (TASK-023, TASK-018) is merged into `dev`. If TASK-001 is close, wait for it too, since it changes what `gitwt remove` does with ignored files. Fold in or coordinate with TASK-017, which fixes specific README claims.

**Result**: `docs/usage.md` covers install, every command and flag, where worktrees go, new worktree setup, how they combine, a settings table, use in scripts, zsh completion, troubleshooting from the actual messages, and known limitations linked to board tasks. The README is now an overview, install, quick start and a link to the guide (306 lines down to about 100). `gitwt help` matched the guide and now links to it. The README quick start was run under zsh, and every relative link and anchor resolves. TASK-017's fixes are folded in, since they were on the same lines.

**Modified files**:
- docs/usage.md (new)
- README.md
- gitwt.sh (help text only)

