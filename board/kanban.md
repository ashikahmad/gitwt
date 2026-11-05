# Kanban Board

<!-- Config: Last Task ID: 21 -->
<!-- Format: v3 -->

## ⚙️ Configuration

**Columns**: 📥 Backlog (backlog) | 📝 To Do (todo) | 🚀 In Progress (in-progress) | 👀 In Review (in-review) | ✅ Done (done)

**Categories**: CLI, Shell Integration, Install, Tests, Documentation

**Users**: @ashikahmad (Ashik Uddin Ahmad)

**Priorities**: 🔴 Critical | 🟠 High | 🟡 Medium | 🟢 Low

**Tags**: #bug #feature #refactor #docs #test

---

## Tasks

### TASK-001 | Protect ignored files when removing a worktree
**Status**: backlog  
**Priority**: High  
**Category**: CLI  
**Created**: 2026-11-05  
**Tags**: #bug #feature  

`gitwt remove` relies on `git worktree remove` (gitwt.sh:243), which refuses modified, staged and untracked files but deletes ignored files without warning. A test worktree with an ignored `.env` was removed with exit 0 and the file was gone for good. gitwt also has no `--force` flag of its own, so forcing means dropping to raw git.

**Subtasks**:
- [ ] List ignored files before removing and warn or ask for confirmation
- [ ] Add `gitwt remove --force`
- [ ] Add tests for ignored files and `--force`
- [ ] Document what removal does and does not protect

### TASK-002 | Make the failed-removal tip accurate about --force
**Status**: backlog  
**Priority**: Medium  
**Category**: CLI  
**Created**: 2026-11-05  
**Tags**: #bug  

When removal fails, gitwt.sh:244 suggests `git worktree remove --force` whatever the cause, and does not say that it permanently discards the uncommitted work git was protecting. The main worktree gets the same tip, although `--force` cannot remove it.

**Subtasks**:
- [ ] Say that `--force` discards uncommitted work
- [ ] Only suggest `--force` when it applies

### TASK-003 | Add gitwt move to relocate or rename a worktree
**Status**: backlog  
**Priority**: Medium  
**Category**: CLI  
**Created**: 2026-11-05  
**Tags**: #feature  

gitwt has no move or rename command. `git branch -m` works and `gitwt sw` still finds the branch, but the folder keeps the old name (`feature/new` stays in `feature-old`). `git worktree move` works and gitwt picks up the new path, but it has to be run by hand. Git cannot move the main worktree or one containing submodules.

**Subtasks**:
- [ ] Decide the interface, e.g. `gitwt move <branch> [path]`
- [ ] Keep the folder name in step with a renamed branch
- [ ] Give a clear error for the main worktree and submodule cases
- [ ] Add tests, zsh completion and docs

### TASK-004 | Automate new worktree setup with .worktreeinclude and a post-create hook
**Status**: backlog  
**Priority**: Medium  
**Category**: CLI  
**Created**: 2026-11-05  
**Tags**: #feature  

gitwt has no setup step, so ignored files and project setup must be redone by hand in every new worktree. Git's `post-checkout` hook does fire on `gitwt new`, but it also fires on ordinary checkouts, and hooks in `.git/hooks` are not versioned or shared. Similar tools combine a list of ignored files to copy with post-create commands; `.worktreeinclude` is used by Claude Code, wt-cli and PostHog Code.

**Subtasks**:
- [ ] Copy files listed in `.worktreeinclude` (gitignore syntax) into new worktrees
- [ ] Run an optional post-create script from the repo
- [ ] Require approval or opt-in before running a repo-supplied script
- [ ] Add tests and docs

### TASK-005 | Fix infinite loop when --from has no value
**Status**: in-review  
**Priority**: High  
**Category**: CLI  
**Created**: 2026-11-05  
**Started**: 2026-11-05  
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
**Status**: backlog  
**Priority**: Medium  
**Category**: CLI  
**Created**: 2026-11-05  
**Tags**: #bug  

Three related problems around gitwt.sh:237-243. The check is a plain string prefix, so from `feature-x-2`, removing `feature/x` wrongly moves the shell to the main repo (the right worktree is still removed). The cd happens before removal, so a failed removal still leaves you in the main repo. Entering a worktree through a symlink defeats the check, so it is deleted around you and the shell is left in a missing directory; this does not happen if you got there via `gitwt new`.

**Subtasks**:
- [ ] Compare whole path components
- [ ] Only leave the worktree once removal can go ahead
- [ ] Compare physical paths

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
**Status**: backlog  
**Priority**: Medium  
**Category**: Documentation  
**Created**: 2026-11-05  
**Tags**: #docs  

**Subtasks**:
- [ ] README.md:41: replace the `your-username` clone URL with `ashikahmad`
- [ ] README.md:207: change "Git 2.5+" to 2.17+, since `git worktree list --porcelain` needs 2.7 and `git worktree remove` needs 2.17
- [ ] README.md:131: show `✓ clean` instead of `clean`
- [ ] README.md:31: describe all four `list` columns, not just branch and path
- [ ] README.md:19: reword "no sibling folders", since `../worktrees` is one sibling folder; "outside your repo" is accurate

### TASK-018 | Explain worktree path collisions
**Status**: backlog  
**Priority**: Low  
**Category**: CLI  
**Created**: 2026-11-05  
**Tags**: #bug  

`feature/a-b`, `feature-a/b`, `feature/a/b` and `feature-a-b` can coexist in git but all map to the slug `feature-a-b`. The second `gitwt new` fails with `worktree path already exists` and a `gitwt list` tip, without naming the collision or the branch that owns the path.

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
