# Task Archive

<!-- Format: v3 -->

> Archived tasks

## ✅ Archives

### TASK-025 | Core worktree commands: new, switch, remove, list
**Status**: done  
**Priority**: Medium  
**Category**: CLI  
**Created**: 2026-04-04  
**Started**: 2026-04-04  
**Finished**: 2026-04-04  
**Tags**: #feature #history  

A shell function wrapping `git worktree`, so you can create a worktree and `cd` into it, jump between worktrees by branch name, and remove them without remembering paths.

**Subtasks**:
- [x] `gitwt new <branch>` creates the branch and worktree, then `cd`s into it
- [x] `gitwt switch`/`sw <branch>` `cd`s into a worktree found by branch name
- [x] `gitwt remove <branch>` removes a worktree and returns you to the main repo if you were inside it
- [x] `gitwt list`/`ls` lists worktrees
- [x] Worktrees go to `../worktrees/<repo>/<type>-<branch>` by default
- [x] `gitwt help`

**Notes**:
**History**: Recorded after the fact: this was built before the project board existed (started 2026-11-05). Dates come from the commits. Commits: `38ca200`.

**Modified files**:
- gitwt.sh
- README.md

### TASK-026 | Installer for zsh and bash
**Status**: done  
**Priority**: Medium  
**Category**: Install  
**Created**: 2026-04-04  
**Started**: 2026-04-04  
**Finished**: 2026-04-04  
**Tags**: #feature #history  

`install.sh` copies `gitwt.sh` and `_gitwt` to `~/.config/gitwt/` and adds the source lines to `~/.zshrc` and/or `~/.bashrc`.

**Subtasks**:
- [x] Copy the scripts to `~/.config/gitwt/`
- [x] Add source lines to the shell config files that exist, without duplicating them

**Notes**:
**History**: Recorded after the fact: this was built before the project board existed (started 2026-11-05). Dates come from the commits. Commits: `38ca200`, `5ed59e3`.
**Known issues**: TASK-008 and TASK-022 cover cases where the installer reports success wrongly or handles earlier installs badly.

**Modified files**:
- install.sh
- README.md

### TASK-027 | Zsh tab-completion
**Status**: done  
**Priority**: Medium  
**Category**: Shell Integration  
**Created**: 2026-04-04  
**Started**: 2026-04-04  
**Finished**: 2026-05-26  
**Tags**: #feature #history  

`_gitwt` completes subcommands, branch names and flags in zsh.

**Subtasks**:
- [x] Complete subcommands and their aliases
- [x] Complete local branches for `new`, and worktree branches for `switch` and `remove`
- [x] Offer `--from` and `--fetch` as soon as you tab after `gitwt new`
- [x] Offer `--branch` for `remove`

**Notes**:
**History**: Recorded after the fact: this was built before the project board existed (started 2026-11-05). Dates come from the commits. Commits: `38ca200`, `67d14e9`, `b59c76f`.

**Modified files**:
- _gitwt

### TASK-028 | One new command for new and existing branches, with --from and --fetch
**Status**: done  
**Priority**: Medium  
**Category**: CLI  
**Created**: 2026-05-26  
**Started**: 2026-05-26  
**Finished**: 2026-05-26  
**Tags**: #feature #history  

`gitwt new` works out what to do: if the branch exists locally it attaches a worktree, otherwise it creates the branch first. The separate `add` command was removed.

**Subtasks**:
- [x] Attach a worktree when the branch already exists, create it otherwise
- [x] `--from <base>` branches off another branch instead of the current one
- [x] `--fetch` fetches the base from its configured remote first; if local and remote have diverged, it asks whether to branch from remote or local, or stop
- [x] Replace the old `--pull` flag, so nothing is merged or rebased
- [x] Turn multi-slash branch names into one folder name (`feature/auth/oauth` becomes `feature-auth-oauth`)

**Notes**:
**History**: Recorded after the fact: this was built before the project board existed (started 2026-11-05). Dates come from the commits. Commits: `6c50110`, `40bc15d`.

**Modified files**:
- gitwt.sh
- _gitwt
- README.md

### TASK-029 | remove --branch to also delete the local branch
**Status**: done  
**Priority**: Medium  
**Category**: CLI  
**Created**: 2026-05-26  
**Started**: 2026-05-26  
**Finished**: 2026-05-26  
**Tags**: #feature #history  

`gitwt remove <branch> --branch` removes the worktree and then deletes the local branch.

**Subtasks**:
- [x] Delete with `git branch -d`, so an unmerged branch is never lost silently
- [x] Offer `--branch` in zsh completion

**Notes**:
**History**: Recorded after the fact: this was built before the project board existed (started 2026-11-05). Dates come from the commits. Commits: `b59c76f`.

**Modified files**:
- gitwt.sh
- _gitwt
- README.md

### TASK-030 | list as a status table
**Status**: done  
**Priority**: Medium  
**Category**: CLI  
**Created**: 2026-05-26  
**Started**: 2026-05-26  
**Finished**: 2026-05-27  
**Tags**: #feature #history  

`gitwt list`/`ls` shows every worktree in a BRANCH · SYNC · CHANGES · PATH table. A short-lived separate `status` command was merged into it.

**Subtasks**:
- [x] SYNC shows ahead/behind against the upstream, or `-` when there is none
- [x] CHANGES counts staged, modified and untracked files, or shows `✓ clean`
- [x] Show detached worktrees as `(detached:<sha>)` instead of dropping them
- [x] Mark worktrees missing on disk as `(stale)` and suggest `git worktree prune`; `switch` and `remove` give the same tip

**Notes**:
**History**: Recorded after the fact: this was built before the project board existed (started 2026-11-05). Dates come from the commits. Commits: `00756ed`, `1751c3d`, `809f9ab`, `6e8e9b9`, `fd96859`.
**Known issues**: TASK-019 covers column alignment and bare repo display.

**Modified files**:
- gitwt.sh
- _gitwt
- README.md
- test/list.bats

### TASK-031 | version command
**Status**: done  
**Priority**: Medium  
**Category**: CLI  
**Created**: 2026-05-26  
**Started**: 2026-05-26  
**Finished**: 2026-05-26  
**Tags**: #feature #history  

`gitwt version`, `--version` and `-v` print the version.

**Subtasks**:
- [x] Print `gitwt <version>`
- [x] Keep the version variable local to `gitwt()`, so it doesn't leak into the shell

**Notes**:
**History**: Recorded after the fact: this was built before the project board existed (started 2026-11-05). Dates come from the commits. Commits: `5ed59e3`.

**Modified files**:
- gitwt.sh
- _gitwt
- README.md
- install.sh

### TASK-032 | bats test suite
**Status**: done  
**Priority**: Medium  
**Category**: Tests  
**Created**: 2026-05-26  
**Started**: 2026-05-26  
**Finished**: 2026-05-26  
**Tags**: #test #history  

A bats-core suite covering `new`, `switch`, `remove`, `list` and `version`, with happy paths and error cases. It started at 29 tests.

**Subtasks**:
- [x] Add bats-core, bats-support and bats-assert as submodules
- [x] Add a runner that captures where gitwt leaves the shell
- [x] Fix `gitwt list` returning 1 when there were no stale worktrees

**Notes**:
**History**: Recorded after the fact: this was built before the project board existed (started 2026-11-05). Dates come from the commits. Commits: `30a5729`.
**Known issues**: TASK-015 and TASK-016 cover zsh, CI and running the suite from a fresh clone.

**Modified files**:
- run_tests.sh
- test/*.bats
- test/test_helper.bash
- test/run_gitwt.sh
- gitwt.sh
