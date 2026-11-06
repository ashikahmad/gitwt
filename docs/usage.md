# gitwt usage guide

Everything gitwt does, how to use it, and what happens when something goes wrong. For a short overview, see the [README](../README.md).

- [Install](#install)
- [Commands](#commands): [`new`](#gitwt-new), [`switch`](#gitwt-switch), [`remove`](#gitwt-remove), [`list`](#gitwt-list), [`version` and `help`](#gitwt-version-and-gitwt-help)
- [Where worktrees go](#where-worktrees-go)
- [Setting up new worktrees](#setting-up-new-worktrees)
- [How it fits together](#how-it-fits-together)
- [Settings](#settings)
- [Using gitwt in scripts](#using-gitwt-in-scripts)
- [Zsh tab-completion](#zsh-tab-completion)
- [Troubleshooting](#troubleshooting)
- [Known limitations](#known-limitations)

---

## Install

gitwt is a shell function, so it has to be sourced into your shell rather than run as a program. That's what lets it `cd` you into a worktree.

**Requirements:** git 2.18 or newer, and zsh or bash.

**Tested with** zsh 5.9 and bash 5.2. bash 3.2, the version macOS ships as `/bin/bash`, isn't tested or officially supported: gitwt may work there, but changes aren't checked against it. On macOS, the default shell is zsh, which is supported.

**With the installer:**

```bash
git clone https://github.com/ashikahmad/gitwt.git
cd gitwt
bash install.sh
source ~/.zshrc    # or: source ~/.bashrc
```

`install.sh` copies `gitwt.sh` and `_gitwt` to `~/.config/gitwt/` and adds source lines to `~/.zshrc` and `~/.bashrc`. It only edits files that already exist, and it skips a line that's already there. zsh also gets the tab-completion line.

**By hand:**

```bash
mkdir -p ~/.config/gitwt
cp gitwt.sh _gitwt ~/.config/gitwt/
```

Then add to `~/.zshrc` or `~/.bashrc`:

```bash
source "$HOME/.config/gitwt/gitwt.sh"
source "$HOME/.config/gitwt/_gitwt"   # zsh only, after compinit
```

**To update**, pull the clone and run `bash install.sh` again, or copy the two files again.

**A shorter name:** `alias gwt=gitwt` in your shell config.

---

## Commands

All commands work from the main repo or from any of its worktrees.

### `gitwt new`

```text
gitwt new <branch> [--from <base>] [--fetch]
```

Creates a worktree for `<branch>` and `cd`s you into it.

| Situation | What happens |
|---|---|
| `<branch>` doesn't exist locally | Creates it from the current branch, or from `--from <base>`, then adds the worktree |
| `<branch>` exists locally | Adds a worktree for it. `--from` and `--fetch` are ignored, with a note |
| `<branch>` already has a worktree | Stops: use `gitwt switch <branch>` |
| The target folder already exists | Stops and says what's using it (see [Path clashes](#path-clashes)) |

```bash
gitwt new feature/dark-mode                       # branch off the current branch
gitwt new feature/dark-mode --from develop        # branch off develop
gitwt new feature/dark-mode --from main --fetch   # fetch main first, then branch off it
gitwt new fix/login-bug                           # existing branch: just add a worktree
```

**`--from <base>`** must be a local branch. `--from=<base>` also works.

**`--fetch`** fetches the base branch from its remote first (`origin`, unless the branch is set up to track another remote), then compares:

| Local base vs. remote | Branches from |
|---|---|
| Same | Local base |
| Behind | The remote branch, e.g. `origin/main` |
| Ahead | Local base |
| Diverged | You choose: 1) remote, 2) local, 3) stop |

After the worktree is created, gitwt [sets it up](#setting-up-new-worktrees) (copies listed files, runs your setup script) and moves you into it.

### `gitwt switch`

```text
gitwt switch <branch>      # alias: gitwt sw <branch>
```

`cd`s into the worktree that has `<branch>` checked out. It looks the path up from git, so it finds any worktree, wherever it is and however it was created.

### `gitwt remove`

```text
gitwt remove <branch> [--branch] [--force]
```

Removes the worktree that has `<branch>` checked out. If your shell is inside it, gitwt moves you to the main repo, but only once removal is going ahead: if it's refused, you stay where you are.

Before removing, gitwt checks that nothing would be lost:

| In the worktree | What happens |
|---|---|
| Uncommitted changes or untracked files | Refuses. Commit or stash them first |
| A file listed in [`.worktreeinclude`](#copy-ignored-files-worktreeinclude), unchanged from the main repo's copy | Removes it quietly: the main repo still has it |
| A listed file changed in the worktree | Refuses, and prints a `diff` command to compare it with the main repo's copy |
| A listed file that exists only in the worktree | Refuses, and prints a `cp` command to copy it to the main repo. It also warns if the main repo doesn't ignore that file, since a copy there could be committed |
| Other ignored files, such as `node_modules/` or `dist/` | Removes them, and names them in one line. Without a `.worktreeinclude`, it suggests adding one |

gitwt never asks a question here and never writes to the main repo; it refuses and says what to do. So it behaves the same in a terminal and in scripts.

```text
$ gitwt remove feature/x
Error: removing this worktree would lose files listed in .worktreeinclude.
Changed here, so they differ from the main repo's copy. To compare:
  diff '/code/myrepo/.env' '/code/worktrees/myrepo/feature-x/.env'
To remove it anyway and lose them: gitwt remove feature/x --force
```

- **`--force`** skips these checks and removes the worktree anyway, permanently discarding uncommitted work and ignored files. Check what you'd lose first.
- **`--branch`** also deletes the local branch, with `git branch -d`, so a branch with unmerged commits is kept. To delete it anyway: `git branch -D <branch>`.
- **The main repo can't be removed.** `gitwt remove main`, when `main` is checked out in the main repo, is refused.
- **Only the main repo's copy is compared.** gitwt doesn't check other worktrees, and `.worktreeinclude` is read from the main repo, the same list used when [copying files in](#copy-ignored-files-worktreeinclude).

### `gitwt list`

```text
gitwt list                 # alias: gitwt ls
```

Shows every worktree of the repo (columns narrowed here):

```text
BRANCH               SYNC                 CHANGES                    PATH
───────────────────  ───────────────────  ─────────────────────────  ──────────────────────────────────
main                 ✓ clean              ✓ clean                    myrepo
feature/dark-mode    -                    2 modified · 1 untracked   worktrees/myrepo/feature-dark-mode
fix/login-bug        3 ahead              ✓ clean                    worktrees/myrepo/fix-login-bug
fix/auth             1 ahead · 2 behind   2 modified                 worktrees/myrepo/fix-auth
(detached:abc1234)   -                    1 staged                   worktrees/myrepo/some-worktree
```

| Column | Shows |
|---|---|
| BRANCH | The branch, `(detached:<sha>)`, or `(stale)` for a worktree that's gone from disk |
| SYNC | Commits ahead and behind the branch's upstream. `✓ clean` means in step; `-` means no upstream, or detached |
| CHANGES | Staged, modified and untracked file counts, or `✓ clean` |
| PATH | Relative to the folder that contains the main repo, or the full path when it's elsewhere |

If any worktree is stale, `list` ends with a tip to run `git worktree prune`.

### `gitwt version` and `gitwt help`

`gitwt version` (also `--version`, `-v`) prints the version. `gitwt help`, or `gitwt` alone, prints a summary of commands and settings.

---

## Where worktrees go

By default, a new worktree goes next to your repo:

```text
../worktrees/<repo>/<slug>
```

The slug is the branch name with each `/` turned into `-`:

| Branch | Worktree |
|---|---|
| `feature/dark-mode` | `../worktrees/myrepo/feature-dark-mode` |
| `feature/auth/oauth` | `../worktrees/myrepo/feature-auth-oauth` |
| `hotfix` | `../worktrees/myrepo/hotfix` |

### Choose your own layout: `gitwt.path`

Set the `gitwt.path` git config to a template:

```bash
git config --global gitwt.path '~/worktrees/{repo}/{slug}'   # all your repos
git config gitwt.path '.worktrees/{slug}'                    # this repo only
git config --unset gitwt.path                                # back to the default
```

| Placeholder | For `feature/dark-mode` in `myrepo` |
|---|---|
| `{repo}` | `myrepo`, the main repo's folder name |
| `{slug}` | `feature-dark-mode` |
| `{branch}` | `feature/dark-mode`, which makes nested folders |

| `gitwt.path` | Worktree |
|---|---|
| `../worktrees/{repo}/{slug}` (default) | `../worktrees/myrepo/feature-dark-mode` |
| `../{repo}-worktrees/{slug}` | `../myrepo-worktrees/feature-dark-mode` |
| `../{repo}-{slug}` | `../myrepo-feature-dark-mode` |
| `~/worktrees/{repo}/{branch}` | `~/worktrees/myrepo/feature/dark-mode` |
| `.worktrees/{slug}` | `.worktrees/feature-dark-mode`, inside the repo |

**Rules:**

- The template must contain `{slug}` or `{branch}`, or every worktree would get the same folder.
- Only `{repo}`, `{slug}` and `{branch}` are allowed.
- Use `~` for your home folder. Shell variables such as `$HOME` aren't expanded, so they're rejected.
- Relative paths start from the main repo's root, wherever you run gitwt from.
- It's a normal git setting: a repo's value beats the global one, and `includeIf` can set it per folder. A cloned repo can't set it for you.
- Changing it only affects new worktrees. Existing ones stay where they are, and `switch`, `remove` and `list` still find them.

gitwt checks the template before creating anything, so a bad one never leaves a half-made branch.

### Worktrees inside the repo

With a path like `.worktrees/{slug}`, the main repo sees each worktree as an untracked folder. gitwt notices and tells you how to hide it on your machine:

```bash
echo '.worktrees/' >> .git/info/exclude
```

Or add `.worktrees/` to `.gitignore` to hide it for everyone.

### Path clashes

Different branches can map to the same folder:

- With `{slug}`, `feature/a-b`, `feature-a/b` and `feature-a-b` all become `feature-a-b`.
- A global template without `{repo}` puts every repo's worktrees in one folder.
- Two repos with the same folder name clash even with `{repo}`.

When the folder is taken, `gitwt new` stops without creating anything and says what's there: another branch's worktree, a detached worktree, a checkout of another repo, or something that isn't a worktree. Using `{branch}` instead of `{slug}` keeps the first kind apart.

---

## Setting up new worktrees

A new worktree has your committed files but not your ignored ones (such as `.env`), and nothing installed. `gitwt new` can do both, every time, for new and existing branches.

### Copy ignored files: `.worktreeinclude`

Create `.worktreeinclude` in the main repo's root, using gitignore syntax:

```gitignore
.env
.env.local
config/*.json
```

On `gitwt new`, a file is copied from the main repo into the new worktree when it matches this list **and** git ignores it. So a listed file that's committed, or untracked but not ignored, is left alone.

- Files always come from the main repo, even if you run `gitwt new` inside another worktree.
- Anything already in the new worktree is kept, not overwritten.
- Folders, file permissions and symlinks are kept.
- `.worktreeinclude` doesn't have to be committed: it's read from the main repo's folder.

### Run a setup script

gitwt can run a script inside each new worktree, for example to install dependencies. Which script:

| `gitwt.postCreate` | `.gitwt/post-create` exists | Runs |
|---|---|---|
| Not set | No | Nothing |
| Not set | Yes | `.gitwt/post-create` |
| Set to a path | Either | Only that file |
| Set to `""` | Either | Nothing: setup is off |

**A gitwt-only script:** commit an executable `.gitwt/post-create`:

```bash
mkdir -p .gitwt
printf '#!/bin/sh\nset -e\nnpm install\n' > .gitwt/post-create
chmod +x .gitwt/post-create
git add .gitwt/post-create && git commit -m "Add worktree setup script"
```

**A script you also run by hand,** such as `scripts/setup.sh`:

```bash
git config gitwt.postCreate scripts/setup.sh            # this repo
git config --global gitwt.postCreate scripts/setup.sh   # every repo that has it
```

The path is relative to the repo root and must stay inside the repo. If it's missing, not executable or outside the repo, gitwt warns and runs nothing; it doesn't fall back to `.gitwt/post-create`.

**What the script gets:**

| | |
|---|---|
| Working folder | The new worktree |
| `GITWT_BRANCH` | The branch name |
| `GITWT_WORKTREE` | The new worktree's full path |
| `GITWT_MAIN_ROOT` | The main repo's full path |
| Files | Anything from `.worktreeinclude` is already copied |
| Input | Your terminal, so it can ask questions |

The `GITWT_*` variables are only set when gitwt runs the script, so a script you also run by hand should work without them.

**Requirements:** the script needs a shebang line (`#!/bin/sh`) and the executable bit. git stores that bit; on Windows, use `git update-index --chmod=+x <file>`. The script is read from the new worktree, so the branch you create or attach must contain it.

### Approving the script

The script comes from the repo, and a branch can change it, so gitwt asks before running a version it hasn't seen:

```text
This repo has a setup script that hasn't been approved: …/scripts/setup.sh
Review it first if you're unsure. Run it now and whenever it's unchanged? [y/N]
```

- **`y`** saves the script's fingerprint and runs it. It runs without asking until the script changes.
- **Anything else** skips it this time and saves nothing.
- **No terminal** (scripts, CI): an unapproved script is skipped with a note.

The approval is stored in the repo's local git config, so it's shared by all its worktrees. Only one version is approved at a time: branches with different versions each ask again. It covers only the script file; if the script runs other files from the repo, changes to those aren't checked, so review what it calls too.

```bash
git config --get gitwt.postCreateApproved                                                 # what's approved
git config gitwt.postCreateApproved "$(git hash-object --no-filters .gitwt/post-create)"  # approve without the prompt
git config --unset gitwt.postCreateApproved                                               # ask again next time
```

For `gitwt.postCreate`, use that file's path in the `hash-object` command.

### When setup fails

If a listed file can't be copied, or the script fails, or `gitwt.postCreate` points at an unusable file:

- you get a warning,
- the worktree is kept and you're moved into it,
- the rest of setup still runs (a failed copy doesn't skip the script),
- `gitwt new` returns 1.

There's no command to rerun setup. Fix the cause, then run the script by hand from the worktree, setting the `GITWT_*` variables yourself if it uses them.

---

## How it fits together

`gitwt new` works in this order:

1. Check the branch has no worktree yet.
2. Work out the path from `gitwt.path`, and stop if the template is invalid or the folder is taken.
3. Create the branch if needed (`--from`, `--fetch`), and add the worktree.
4. If the worktree is inside the main repo and not ignored, print how to hide it.
5. Copy the files listed in the main repo's `.worktreeinclude`.
6. Run the setup script, if there is one and it's approved.
7. `cd` into the worktree.

Some combinations worth knowing:

- **Custom paths and setup work together.** Files are copied and the script runs wherever the worktree goes, including `{branch}` paths and paths through a symlink.
- **Worktrees inside the repo don't copy each other's files.** With `.worktrees/{slug}` and `**/.env` listed, a sibling worktree's `.env` isn't copied into the new one; only the main repo's files are.
- **Symlinked paths:** when `gitwt.path` goes through a symlink, `GITWT_WORKTREE` holds the path through the symlink, not the resolved one. Both work.
- **One list, both ways.** The main repo's `.worktreeinclude` decides what's copied into a new worktree and what's checked before one is removed. An unchanged copy is removed quietly; one you edited, or a listed file you created in the worktree, stops `gitwt remove`.

---

## Settings

All settings are git config keys. Set them per repo with `git config`, or for all repos with `git config --global`.

| Key | Does | Default | Set |
|---|---|---|---|
| `gitwt.path` | Template for new worktree paths | `../worktrees/{repo}/{slug}` | Repo or global |
| `gitwt.postCreate` | Setup script to run instead of `.gitwt/post-create`; `""` turns setup off | Not set: `.gitwt/post-create` | Repo or global |
| `gitwt.postCreateApproved` | Fingerprint of the approved setup script | Not set | Stored by gitwt in the repo's config |

Files gitwt reads:

| File | Read from | Does |
|---|---|---|
| `.worktreeinclude` | Main repo | Lists ignored files to copy into new worktrees |
| `.gitwt/post-create` | New worktree | Default setup script |

---

## Using gitwt in scripts

- **Without a terminal,** an unapproved setup script is skipped. Approve it in advance with the `hash-object` command [above](#approving-the-script).
- **`--fetch` can ask a question** when the branches have diverged. With no answer, it stops.
- **`gitwt new` can return 1 after creating the worktree,** when setup fails. Check the exit status, not just whether the folder exists.
- **Unknown flags aren't rejected yet.** A typo can be taken as a branch name (TASK-007).

---

## Zsh tab-completion

`_gitwt` completes:

- subcommands after `gitwt `,
- for `new`: local branches that don't have a worktree yet, plus `--from` and `--fetch`; after `--from`, all local branches,
- for `switch` and `remove`: branches that have a worktree, plus `--branch` for `remove`.

Source it after `compinit` in `~/.zshrc`. Before `compinit`, zsh prints `command not found: compdef` at startup (TASK-014). bash has no completion yet.

---

## Troubleshooting

| Message | Meaning | Fix |
|---|---|---|
| `branch 'x' already has a worktree` | `x` is checked out in a worktree | `gitwt switch x` |
| `worktree path already exists` | The folder is taken; the next line says by what | See [Path clashes](#path-clashes) |
| `base branch 'x' does not exist locally` | `--from` needs a local branch | `git branch x origin/x`, or pick another base |
| `could not determine current branch` | You're on a detached HEAD, or not in a git repo | Use `--from <base>`, or `cd` into the repo |
| `could not fetch 'x' from 'origin'` | `--fetch` failed | Check the network and `git remote -v` |
| `gitwt.path can't use shell variables` | The template has `$HOME` or similar | Use `~` or a full path |
| `gitwt.path must contain {slug} or {branch}` | Every worktree would get one folder | Add `{slug}` or `{branch}` |
| `gitwt.path has an unknown placeholder` | A typo such as `{rpeo}` | Use `{repo}`, `{slug}` or `{branch}` |
| `… is inside the main repo and not ignored` | The worktree shows as untracked in the main repo | Run the `.git/info/exclude` line it prints |
| `could not copy N file(s) listed in .worktreeinclude` | Something blocked a copy, often a file where a folder should be | Read the `could not copy '<file>'` lines above it |
| `… is not approved, skipping it` | No terminal to ask on | Run `gitwt new` in a terminal, or approve in advance |
| `… is not executable, skipping it` | `.gitwt/post-create` lacks the executable bit | `chmod +x .gitwt/post-create` and commit |
| `gitwt.postCreate is set to '…', but that file doesn't exist in the new worktree` | The branch doesn't have the script | Commit it to the branch, or change `gitwt.postCreate` |
| `gitwt.postCreate is set to '…', but that file isn't executable` | Missing executable bit | `chmod +x <file>` and commit |
| `gitwt.postCreate must be a path inside the repo` | The path is absolute or uses `..` | Use a path relative to the repo root |
| `… failed. The worktree was still created.` | The setup script exited with an error | Fix it and run it by hand in the worktree |
| `no worktree found for branch 'x'` | `x` has no worktree | `gitwt list` |
| `worktree path no longer exists` | The folder was deleted outside git | `git worktree prune` |
| `'x' has uncommitted changes or untracked files` | `remove` won't discard work | Commit or stash, or `gitwt remove x --force` if you're sure |
| `removing this worktree would lose files listed in .worktreeinclude` | A listed file was changed in the worktree, or exists only there | Run the `diff` or `cp` commands it prints, then remove again; or `--force` |
| `isn't ignored in the main repo, so a copy there could be committed` | Copying that file to the main repo would make it committable | Add it to the main repo's `.gitignore` first, or copy it somewhere else |
| `'x' is checked out in the main repo, which isn't a removable worktree` | You named the main repo's branch | Nothing to remove |
| `cannot remove a locked working tree` | The worktree is locked with `git worktree lock` | `git worktree unlock <path>`, then remove again |
| `Tip: branch has unmerged commits` | `--branch` kept the branch | `git branch -D x` if you're sure |

---

## Known limitations

**bash 3.2 isn't tested or officially supported.** That's the version macOS ships as `/bin/bash`. zsh 5.9 and bash 5.2 are tested.

These are tracked on the [project board](https://ashikahmad.github.io/Kanban.md/app/?board=https://github.com/ashikahmad/gitwt/blob/dev/board/kanban.md):

| Task | Limitation |
|---|---|
| TASK-006 | `new` for a branch that exists only on the remote creates a fresh local branch instead of tracking it |
| TASK-007 | Unknown flags and commands aren't rejected |
| TASK-009 | After `--fetch` branches from the remote, the new branch tracks the base branch |
| TASK-010 | `--from` accepts only local branches, not `origin/x`, tags or SHAs |
| TASK-014 | Sourcing `_gitwt` before `compinit` prints an error at zsh startup |
| TASK-020 | `switch` and `remove` can't target a detached worktree |
