<p align="center">
  <img src="icon.svg" width="96" height="96" alt="gitwt icon"/>
</p>

# gitwt

A friendly shell wrapper around `git worktree` that makes working with multiple worktrees fast and intuitive.

Instead of remembering long `git worktree` paths and flags, `gitwt` gives you simple commands — create a new worktree and jump straight into it, switch between worktrees by branch name, and remove them cleanly.

---

## Features

- **`new`** — branch off the current (or any) branch, create a worktree, and `cd` into it in one command
- **`add`** — set up a worktree for an existing branch at a predictable path layout
- **`switch` / `sw`** — jump into any worktree by branch name
- **`remove`** — tear down a worktree; auto-returns you to the main repo if you're inside it
- **`list` / `ls`** — clean table of all worktrees with branch and relative path
- **Zsh tab-completion** via the included `_gitwt` completion script

---

## Installation

### Quick install (recommended)

```bash
git clone https://github.com/your-username/gitwt.git
cd gitwt
bash install.sh
```

Then reload your shell:

```bash
# bash
source ~/.bashrc

# zsh
source ~/.zshrc
```

### Manual install

1. Copy the files to a permanent location:

```bash
mkdir -p ~/.config/gitwt
cp gitwt.sh ~/.config/gitwt/gitwt.sh
cp _gitwt   ~/.config/gitwt/_gitwt
```

2. Add to your `~/.bashrc` or `~/.zshrc`:

```bash
# For bash and zsh
source "$HOME/.config/gitwt/gitwt.sh"

# For zsh tab-completion (zsh only)
source "$HOME/.config/gitwt/_gitwt"
```

3. Reload your shell.

---

## Usage

```
gitwt <command> [args]
```

### `gitwt new <branch-name>`

Branch off the current branch (or `--from <base>`), create a worktree, and `cd` into it immediately.

```bash
gitwt new feature/dark-mode                        # branch off current branch
gitwt new feature/dark-mode --from develop         # branch off develop
gitwt new feature/dark-mode --from main --pull     # pull main first, then branch off it
```

### `gitwt add <branch-name>`

Create a worktree for an **existing** branch at the conventional path layout.

```bash
gitwt add fix/checkin-timeout-issue-103
# → ../worktrees/<repoName>/fix-checkin-timeout-issue-103
```

### `gitwt switch <branch-name>` (alias: `sw`)

`cd` into an existing worktree by branch name.

```bash
gitwt sw feature/dark-mode
gitwt sw main
```

### `gitwt remove <branch-name>`

Remove a worktree. If your shell is currently inside that worktree, it automatically navigates back to the main repo root.

```bash
gitwt remove feature/dark-mode
```

### `gitwt list` (alias: `ls`)

List all registered worktrees with their branch and relative path.

```
BRANCH                                   PATH
────────────────────────────────────── ──────────────────────────────────────
main                                   myrepo
feature/dark-mode                      worktrees/myrepo/feature-dark-mode
fix/login-bug                          worktrees/myrepo/fix-login-bug
```

---

## Worktree path layout

Worktrees are placed at a predictable location relative to your main repo:

```
../worktrees/<repoName>/<type>-<branch-name>
```

Examples:

| Branch | Worktree path |
|---|---|
| `feature/dark-mode` | `../worktrees/myrepo/feature-dark-mode` |
| `fix/checkin-timeout` | `../worktrees/myrepo/fix-checkin-timeout` |
| `hotfix` | `../worktrees/myrepo/hotfix` |

---

## Typical workflow

```bash
# See all current worktrees
gitwt ls

# Start a new feature (branch off current + worktree + cd in)
gitwt new feature/dark-mode

# Start from a specific base branch
gitwt new feature/dark-mode --from develop --pull

# Add a worktree for an existing branch
gitwt add fix/login-bug

# Jump between worktrees
gitwt sw main
gitwt sw feature/dark-mode

# Remove when done
gitwt remove feature/dark-mode
```

---

## Zsh tab-completion

The `_gitwt` completion script provides context-aware tab-completion:

- Subcommand names are completed after `gitwt `
- `gitwt new` suggests `--from` and `--pull` flags; completing after `--from` lists local branches
- `gitwt add` lists local branches that don't already have a worktree
- `gitwt switch` and `gitwt remove` list only branches that have an active worktree

The `install.sh` script adds the completion source line to `.zshrc` automatically.

---

## Requirements

- Git 2.5+ (worktree support)
- bash or zsh

---

## License

MIT
