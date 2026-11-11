![gitwt icon](icon.svg)

# gitwt

A friendly shell wrapper around `git worktree` that makes working with multiple worktrees fast and intuitive.

Instead of remembering long `git worktree` paths and flags, `gitwt` gives you simple commands — create a new worktree and jump straight into it, switch between worktrees by branch name, and remove them cleanly.

**Website and guide:** https://ashikahmad.github.io/gitwt/

---

## Why gitwt?

**`git worktree` is powerful but awkward to use directly.** You have to supply full filesystem paths, remember where you put each worktree, and run separate commands to create a branch and attach it. `gitwt` fixes that with three core ideas:

**1. Think in branches, not paths.**<br/>
With plain `git worktree`, you manage paths. With `gitwt`, you name a branch — `gitwt sw feature/dark-mode` — and it finds the right directory for you. No memorising where you put things.

**2. Worktrees live outside your repo, automatically.**<br/>
By default, every worktree lands at `../worktrees/<repo>/<branch-slug>` — one predictable folder next to your main repo. Your repo's own directory stays clean, and all worktrees for a project are grouped in one place. Prefer somewhere else? [Set your own layout](docs/usage.md#where-worktrees-go).

**3. Branch and worktree in a single command, without switching first.**<br/>
With raw git you'd need to `git checkout develop && git pull && git checkout -b my-feature` before creating a worktree. `gitwt new my-feature --from develop --fetch` does it all in one shot from wherever you are — no need to leave your current branch.

---

## Features

- **`new`** — create a worktree and `cd` into it in one command; works out whether to create the branch or attach an existing one
- **`switch` / `sw`** — jump into any worktree by branch name
- **`remove`** — tear down a worktree, and optionally its branch; refuses if you'd lose uncommitted work or an edited `.env`, and returns you to the main repo if you're inside it
- **`move` / `mv`** — move a worktree to another folder, or keep its folder name in step with a renamed branch; everything in it moves as is
- **`list` / `ls`** — an instant table of every worktree with its branch, sync with upstream, last commit and path; `ls -l` adds local changes
- **Custom worktree paths** — choose where new worktrees go with a `gitwt.path` template, per repo or for all repos
- **New worktree setup** — copy ignored files such as `.env` and run a setup script automatically
- **Zsh tab-completion** via the included `_gitwt` completion script

---

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/ashikahmad/gitwt/main/install.sh | bash
```

Then open a new terminal. Run the same command again to update. To read the script before running it, or to install from a clone or by hand, see [Install](docs/usage.md#install).

Works on macOS and Linux with zsh (macOS's default shell) or bash 4+, and git 2.18+. bash 3.2, macOS's own `/bin/bash`, isn't supported; the installer asks first if that's your shell. See [What's supported](docs/usage.md#whats-supported).

---

## Quick start

```bash
gitwt ls                                            # see all worktrees
gitwt new feature/dark-mode                         # new branch off the current one, worktree, cd in
gitwt new feature/dark-mode --from main --fetch     # fetch main first, then branch off it
gitwt new fix/existing-branch                       # existing branch: just add a worktree
gitwt new fix/teammates-branch --fetch              # branch on the remote: fetch it and track it
gitwt sw main                                       # jump to another worktree
gitwt move feature/new                              # after git branch -m: rename the folder too
gitwt remove feature/dark-mode --branch             # remove the worktree and its branch
```

Bring ignored files and project setup into every new worktree:

```bash
printf '.env\n' > .worktreeinclude                  # copy .env from the main repo
git config gitwt.postCreate scripts/setup.sh        # run your setup script (asks once)
```

Put worktrees somewhere else:

```bash
git config --global gitwt.path '~/worktrees/{repo}/{slug}'
```

---

## Documentation

The **[usage guide](docs/usage.md)** ([on the website](https://ashikahmad.github.io/gitwt/docs/)) covers every command and option, where worktrees go, setting up new worktrees, all settings, troubleshooting and known limitations. `gitwt help` prints a summary in the terminal.

---

## Project board

Planned work, bugs and ideas are tracked in [`board/kanban.md`](board/kanban.md), a [Kanban.md](https://github.com/ashikahmad/Kanban.md) board. You can also [view it as a board](https://ashikahmad.github.io/Kanban.md/app/?board=https://github.com/ashikahmad/gitwt/blob/dev/board/kanban.md), read-only, in any browser. It shows the `dev` branch, where work lands first.

---

## License

MIT
