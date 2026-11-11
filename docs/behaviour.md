# gitwt behaviour spec

**Status: draft, under review.** This is the target behaviour for every gitwt command, case by case. It says *what* happens, not how it's built. Code and the [usage guide](usage.md) are brought in line with it one command at a time (see [Delivery](#delivery)).

Each case has an ID (`NEW-3`, `RM-8`) so PRs, tests and reviews can point at it. Every case gets a test.

| Mark | Meaning |
|---|---|
| ✓ | Same as today |
| ✎ | Today does something else, or does the same with different wording or exit code |
| ✚ | Today rejects this input or has no way to express it |
| ? | Open: needs a decision (see [Decisions](#decisions)) |

---

## Principles

Every case below follows these. When a case seems to need an exception, the case is wrong.

1. **One rule per parameter.** Each parameter follows one rule, which you can read off the cheat sheet. The rule may look at the repo (is this branch local?), but other parameters never change it. Two flags are themselves rules about the others: `--fetch` (Principle 3) and `--force`, which means "go ahead even though something is lost", wherever gitwt would otherwise refuse because of a loss.
2. **Do it, or fail.** gitwt goes ahead only when it can do what was asked confidently and safely. Otherwise it fails, changes nothing, and, when there is one, says which command to run instead. It doesn't guess, and it doesn't ask; the one exception is approving a repo's setup script (SETUP-2).
3. **No network unless `--fetch`.** `--fetch` means "I want the latest": fetch first, then decide by the same rules, and bring what you named up to date. An existing branch is fast-forwarded to its upstream (NEW-4); a new branch starts from its base as brought up to date (NEW-33); a tag is fetched by name (NEW-37). If that would move something checked out, or the two have diverged, it fails. If yours is already ahead, or the remote has nothing to compare with, gitwt uses yours and says so.
4. **Nothing half-done.** When gitwt fails, nothing has changed, except what `--fetch` already fetched (remote-tracking branches, tags, `FETCH_HEAD`). Exceptions, each of which says so when it happens: setup after a worktree is added (SETUP-1, SETUP-4) keeps the worktree, and a branch that can't be deleted after its worktree was removed (RM-14).
5. **The obvious reading wins.** If a user would read a command one way and gitwt does another, gitwt is wrong, however well it's documented.

---

## Cheat sheet

```text
gitwt new <branch> [--from <base>] [--fetch]      make sure it has a worktree, then cd into it
    <branch>      your local branch; else the one known remote branch of that name; else a new branch
    <remote>/<x>  your local x, created or fast-forwarded to match <remote>/x as of your last fetch;
                  fails if that isn't a fast-forward
    --from <base> where a NEW branch starts: local branch, <remote>/<branch>, tag or commit
    --fetch       fetch the remote(s) involved first, then use the latest: an existing branch is fast-forwarded
                  to its upstream, a new branch starts from its base as brought up to date
gitwt switch <branch>                     cd into that branch's worktree              (alias: sw)
gitwt remove <target> [--branch] [--force]       (alias: rm)
    --branch      also delete the branch, only if none of its commits would be lost
    --force       go ahead even if files in the worktree, or (with --branch) commits, are lost
gitwt move <target> [<path>]              move it to <path>, or to where gitwt.path puts it   (alias: mv)
gitwt list [-l | -s]                      every worktree; -l adds changes, -s is branch and path only   (alias: ls)
gitwt version                             also -v, --version
gitwt help [<command>]                    also -h, --help, or gitwt alone; <command> --help for one command
<target> = (remove, move) a branch that has a worktree, or a worktree's top folder: . .. or a path
           starting with / ./ ../ ~
```

---

## Words used here

| Word | Means |
|---|---|
| Local branch | `refs/heads/<name>` |
| Known remote branch | A remote-tracking branch on this machine, `refs/remotes/<remote>/<name>`, as of the last fetch. `<remote>/HEAD` never counts |
| Upstream | The remote-tracking branch a local branch tracks (`branch.<name>.remote` and `.merge`), whatever its name. A local branch as upstream counts as none. "Gone" means it's set, but the remote-tracking branch no longer exists |
| Lost | Gone with no copy elsewhere: uncommitted changes, untracked files, changed or worktree-only `.worktreeinclude` files, initialised submodules, and commits on no other branch. Ignored files not listed in `.worktreeinclude` don't count; RM-1 names them |
| `<remote>/<x>` form | A name that starts with a configured remote's name and a slash, such as `origin/feature/x` |
| Fetch remote | The remote `--fetch` contacts when nothing else names one: `checkout.defaultRemote` if set; else the only remote; else `origin` if it exists; else none |
| Path (in `<target>`) | `.`, `..`, or anything starting with `/`, `./`, `../` or `~`. Everything else is a branch name, so a `<target>` of `feature/x` is never a folder. `move`'s destination `<path>` is always a path (MV-3) |
| Main repo | The repo's first worktree, the one `git clone` made. It can be switched to, but not removed or moved. (A bare main repo: see Not covered) |
| Stale worktree | One git has registered whose folder is gone |

---

## Everywhere

These apply to every command, before any command-specific case.

| ID | Case | Result | |
|---|---|---|---|
| ALL-1 | An unknown flag, such as `--frm` | Fail with the command's usage. Nothing else runs | ✎ (✓ for `list`) |
| ALL-2 | More arguments than the command takes, such as `gitwt new a b` | Fail with usage | ✎ (✓ for `list`, `move`) |
| ALL-3 | A flag that needs a value has none: `--from` alone, `--from=`, `--from --fetch` | Fail with usage | ✓ |
| ALL-4 | The same flag twice, such as `--fetch --fetch` | Same as once. A second `--from` with a different value fails | ✎ |
| ALL-5 | Flags before, after or between arguments | All the same | ✓ |
| ALL-6 | `--` | Everything after it is an argument, even if it starts with `-` | ✚ |
| ALL-7 | `-h` or `--help` after a command | Print that command's usage, exit 0. Nothing else runs | ✚ |
| ALL-8 | A required argument is missing: `gitwt new`, `remove`, `move` with nothing | Fail with usage | ✓ |
| ALL-9 | An unknown command, such as `gitwt nwe foo` | Fail: `unknown command 'nwe'`, suggesting the closest command if there's a clear one, then the command list. Exit 1. (`rm` is an alias of `remove`, not an unknown command) | ✎ |
| ALL-10 | Not inside a git repo | Fail: `not inside a git repo`. Same wording from every command except `help` and `version`, which work anywhere | ✎ |
| ALL-11 | Running in bash older than 4 | Fail with the "not supported" message, for every command, including help and version | ✓ |
| ALL-12 | Checks before `--fetch` | Syntax (ALL-1 to ALL-8, NEW-49), and anything a fetch can't change: local `x` with `--from` (NEW-6), a detached HEAD with no `--from` and no `--fetch` (NEW-26; with `--fetch`, decided after it), `--from b` that's neither local nor a tag or commit while a known remote has `b` (NEW-38). These fail before any network. Anything that depends on a remote (NEW-12, NEW-13, NEW-31, NEW-36, NEW-37) is decided after the fetch | ✚ |

**Output:** progress goes to stdout, errors and notes to stderr. Exit 0 means it did what was asked; 1 means it failed. A failure starts with `Error:` and ends with the command(s) to run instead, when there are any.

---

## Naming a worktree: `<target>`

`switch`, `remove` and `move` act on an existing worktree. All three take a branch; `remove` and `move` also take a path, since that's the only way to name a detached worktree. `switch` doesn't: to go to a folder, `cd` is shorter and clearer. A branch name is looked up first among local branches, since worktrees hold only local branches.

| ID | `<target>` | Result | |
|---|---|---|---|
| TGT-1 | A branch with a worktree, including a local branch literally named `origin/x` | That worktree | ✓ |
| TGT-2 | `remove`, `move`: a path that is a worktree's top folder | That worktree. This is how detached worktrees are named | ✚ |
| TGT-3 | `remove`, `move`: a path inside a worktree, but not its top folder | Fail, naming the top folder, so `remove ./src` can't remove the whole worktree by accident | ✚ |
| TGT-4 | `switch` with a path | Fail: `switch takes a branch; to go to a folder, use: cd <path>` (SW-2) | ✎ |
| TGT-5 | `remove`, `move`: a path that isn't a worktree's top folder or inside one | Fail: `not a worktree of this repo` | ✚ |
| TGT-6 | A local branch with no worktree | `switch` and `move`: fail, `'x' has no worktree`, naming `gitwt new x`. `remove` without `--branch`: fail, naming `gitwt remove x --branch` to delete the branch. `remove --branch`: RM-16 | ✎ |
| TGT-7 | Not a local branch, but a known remote branch | Fail. `switch` names `gitwt new x`; `remove` and `move` say there's nothing here to act on | ✎ |
| TGT-8 | `<remote>/<x>` form, and no local branch of that name | Fail: worktrees hold local branches. If `x` has a worktree, name `gitwt <command> x`. `switch` otherwise names `gitwt new <remote>/<x>` | ✎ |
| TGT-9 | Nothing of that name | Fail, naming `gitwt list`. If it matches a PATH as `list` shows it (such as `gitwt-x`), name `gitwt <command> <that worktree's full path>` instead | ✎ |
| TGT-10 | A stale worktree, by branch, or (`remove`, `move`) by its old folder | `switch`, `move`: fail, naming `gitwt remove x` to drop that record. `remove`: RM-12 | ✎ |
| TGT-11 | The label `list` shows for a detached worktree, `(detached:abc1234)` | Fail. `switch` prints `cd <full path>`; `remove` and `move` print the full path, which is how to name it | ✚ |

---

## `gitwt new`

```text
gitwt new <branch> [--from <base>] [--fetch]
```

Makes sure `<branch>` has a worktree, then `cd`s you into it.

**What each parameter means:**
- **`<branch>`** is the branch you'll work on. gitwt picks the first that applies: your local branch; else the one known remote branch of that name, which you get as a local branch tracking it; else a new branch.
- **`<remote>/<x>`** means that remote's branch `x`. You get your local branch `x`, made to match it only when that's safe.
- **`--from <base>`** is where a new branch starts. It's looked up in this order: local branch, `<remote>/<branch>`, tag, commit; nothing is guessed. It's only for new branches: if `<branch>` already exists, locally or as a known remote branch, `--from` fails. With `--fetch`, see NEW-33.
- **`--fetch`** means you want the latest. It fetches first, as `git fetch --prune <remote>` would, then decides by the same rules: an existing branch is brought up to its upstream as `<remote>/<x>` would be (NEW-4), and a new branch starts from its base as brought up to date (NEW-33). Which remotes: see [What `--fetch` fetches](#what---fetch-fetches).

New branches never get an upstream. Branches gitwt creates to match a remote branch always track it. Whenever gitwt uses a remote branch from a remote it didn't fetch in this run, it says `as of your last fetch`.

### A local branch

| ID | Command | Situation | Result | |
|---|---|---|---|---|
| NEW-1 | `new x` | `x` has a worktree, the main repo included | Switch to it: `'x' already has a worktree — switching to it` | ✎ |
| NEW-2 | `new x` | `x` has a worktree, but its folder is gone | Drop that stale record (as RM-12), then add a fresh worktree (NEW-3), saying so. If the record is locked, fail as RM-13 | ✎ |
| NEW-3 | `new x` | `x` has no worktree | Add one, set it up, switch to it | ✓ |
| NEW-4 | `new x --fetch` | `x` exists and tracks a remote branch `<remote>/<u>` (`u` may differ from `x`), still there after the fetch | Fetch `<remote>`, then compare `x` with `<remote>/<u>`: same commit, use `x` (NEW-1 or NEW-3); behind with no worktree, fast-forward `x` and add one (as NEW-15); behind with a worktree, fail for safety, naming `git -C <path> merge --ff-only <remote>/<u>` (as NEW-16); ahead, use `x` and say so; diverged, fail (as NEW-17b) | ✎ |
| NEW-4a | `new x --fetch` | `x`'s upstream is gone after the fetch (deleted on the remote, often after a merge) | Use `x` (NEW-1 or NEW-3), noting `'<remote>/<u>' no longer exists` | ✎ |
| NEW-5 | `new x --fetch` | `x` exists, with no upstream or a local branch as upstream | Note `'x' has no remote upstream, so nothing was fetched`. If a known remote has `x`, add `to track it: git branch -u <remote>/x x`. Then NEW-1 or NEW-3 | ✎ |
| NEW-6 | `new x --from b` | `x` exists | Fail: `'x' already exists`. To use it: `gitwt new x` | ✎ |

### A branch only a remote has

| ID | Command | Situation | Result | |
|---|---|---|---|---|
| NEW-7 | `new x` | Not local; one known remote has `x` | Create local `x` tracking `<remote>/x`, add a worktree | ✎ |
| NEW-8 | `new x` | Not local; several known remotes have `x`, and `checkout.defaultRemote` is one of them | As NEW-7, with that remote | ✎ |
| NEW-9 | `new x` | Not local; several known remotes have `x`, and `checkout.defaultRemote` isn't set to one of them | Fail, naming `gitwt new <remote>/x` for each | ✎ |
| NEW-10 | `new x --from b` | Not local; a known remote has `x` | Fail: `'x' already exists on '<remote>'`. To work on it: `gitwt new x`. For a new branch: pick another name. If it was deleted there, add `--fetch` to refresh | ✎ |

### Naming the remote: `<remote>/<x>`

These cases apply when local `x` tracks `<remote>/x` or has no upstream; when it tracks anything else, NEW-18.

| ID | Command | Situation | Result | |
|---|---|---|---|---|
| NEW-11 | `new origin/x` | No local `x`; `origin/x` known | Create local `x` tracking `origin/x`, add a worktree. Folder and branch are `x` | ✎ |
| NEW-12 | `new origin/x` | `origin/x` not known | Fail: `not on 'origin' as of your last fetch`. Add `--fetch` | ✎ |
| NEW-13 | `new origin/x --fetch` | After the fetch, `origin` has no `x` | Fail: `'origin' has no branch 'x'` | ✎ |
| NEW-14 | `new origin/x` | Local `x` at the same commit as `origin/x` | Use local `x`: NEW-1 or NEW-3 | ✎ |
| NEW-15 | `new origin/x` | Local `x` behind `origin/x`, no worktree | Fast-forward `x` to `origin/x` and add a worktree for it, and say so. If either step fails, `x` is back where it was and there's no new worktree | ✎ |
| NEW-16 | `new origin/x` | Local `x` behind `origin/x`, has a worktree | Fail: `'x' is checked out at <path>, N commits behind 'origin/x'`. To update it there: `git -C <path> merge --ff-only origin/x` | ✎ |
| NEW-17a | `new origin/x` | Local `x` ahead of `origin/x` (it has everything `origin/x` has) | Use local `x`: NEW-1 or NEW-3, noting `'x' is N commits ahead of 'origin/x'` | ✎ |
| NEW-17b | `new origin/x` | Local `x` diverged from `origin/x` | Fail: `'x' and 'origin/x' have diverged`. For your local `x`: `gitwt new x`. For `origin/x` on a new branch: `gitwt new <name> --from origin/x` | ✎ |
| NEW-18 | `new origin/x` | Local `x` tracks something other than `origin/x` | Fail: `'x' tracks '<other>'`. For your local `x`: `gitwt new x` | ✎ |
| NEW-19 | `new origin/x` | Local `x` has no upstream, and NEW-14, NEW-15 or NEW-17a applies | As that case, and set `x` to track `origin/x`; say so. If the case fails, the upstream isn't changed | ✎ |
| NEW-20 | `new origin/x` | Local `x`'s worktree folder is gone | As NEW-2 | ✎ |
| NEW-21 | `new origin/x --from b` | Any | Fail: `--from` is only for new branches, and `origin/x` isn't new | ✎ |
| NEW-22 | `new origin/x`, or `--from origin/x` | A local branch is literally named `origin/x`, and `origin/x` is also a known remote branch | Use the local branch, as git does: NEW-1 or NEW-3 (or NEW-28 for `--from`). Note `using your local branch 'origin/x', not the remote's 'x'`; to reach the remote's, rename the local one with `git branch -m origin/x <new-name>` | ✎ |
| NEW-23 | `new origin/x` | A local branch named `origin/x`, and no known remote branch `origin/x` | Use the local branch: NEW-1 or NEW-3 | ✓ for NEW-3, ✎ for NEW-1 |
| NEW-24 | `new origin/HEAD`, `--from origin/HEAD` | Any | Fail: `HEAD` isn't a branch. Name `<remote>/<branch>` | ✎ |

### A new branch

| ID | Command | Situation | Result | |
|---|---|---|---|---|
| NEW-25 | `new x` | Nowhere: not local, not a known remote branch | Create `x` from the current branch (the one checked out where you run the command), no upstream | ✓ |
| NEW-26 | `new x` | Nowhere, and you're on a detached HEAD | Fail: `no current branch to start from`. Name `gitwt new x --from <branch or commit>` | ✎ |
| NEW-27 | `new up/x` | `up` isn't a remote | `up/x` is an ordinary branch name: NEW-25. Output says `new branch 'up/x'` | ✓ |
| NEW-28 | `new x --from b` | `x` new; `b` a local branch | Create `x` from `b`, no upstream. A tag also called `b` doesn't matter: the branch comes first | ✎ |
| NEW-29 | `new x --from origin/b` | `x` new; `origin/b` known | Create `x` from `origin/b`, no upstream | ✚ |
| NEW-30 | `new x --from v1.2` | `x` new; a tag or commit | Create `x` from it, no upstream | ✚ |
| NEW-31 | `new x --from b` | `b` doesn't exist in any of those forms | Fail. If a known remote has `b`, name `--from <remote>/b` | ✎ |
| NEW-31a | `new x --from origin/b` | `origin/b` isn't known | Fail: `not on 'origin' as of your last fetch`. Add `--fetch` | ✎ |

### `--fetch` with a new branch

The base is `--from b`, or the current branch when there's no `--from`. Its upstream is whatever it's set to track, whatever the name (`dev` can track `origin/develop`).

| ID | Command | Situation | Result | |
|---|---|---|---|---|
| NEW-32 | `new x --fetch` | After the fetch, `x` is on the fetched remote | NEW-7: track it | ✎ |
| NEW-33 | `new x --fetch`, `new x --from b --fetch` | After the fetch, `x` is nowhere; the local base has an upstream | Start from whichever of the base and its upstream contains the other, and say which. No upstream on `x` | ✎ |
| NEW-34 | same | The base and its upstream have diverged | Fail: `'b' and 'origin/b' have diverged`. Name `--from origin/b`, and `--from b` without `--fetch` | ✎ |
| NEW-35 | same | The local base has no upstream, a local branch as upstream, or its upstream is gone | Start from the local base, noting `'b' has no remote upstream` or `'<remote>/<u>' no longer exists`, the same wording as NEW-5 and NEW-4a | ✎ |
| NEW-36 | `new x --from origin/b --fetch` | `x` new | Start from `origin/b` as just fetched. If `origin` has no `b`, fail | ✚ |
| NEW-37 | `new x --from v1.2 --fetch` | A tag or commit | A tag: fetch it by name from the fetch remote (a plain `git fetch` skips tags no branch reaches, and keeps an old copy of a tag that moved). If the remote moved a tag you already have, fail, naming `git fetch <remote> --force tag v1.2`. If the remote doesn't have it, use yours and say so. A commit: fetch the fetch remote, then NEW-30 | ✚ |
| NEW-38 | `new x --from b --fetch` | `b` isn't local, but a known remote has `b` | Fail before fetching (ALL-12), naming `--from <remote>/b --fetch` | ✎ |
| NEW-39 | `new x --from b --fetch` | After the fetch, a remote has `x` | NEW-10: fail | ✎ |

### What `--fetch` fetches

gitwt runs `git fetch --prune <remote>` once for each remote involved, before deciding anything. Unrelated remotes are never contacted.

| ID | Situation | Remotes fetched | |
|---|---|---|---|
| NEW-40 | `<remote>/<x>` form | That remote | ✎ |
| NEW-41 | Local `x` (NEW-4) | `x`'s upstream remote | ✎ |
| NEW-42 | Bare `x` that isn't local | The fetch remote, every remote where `x` is known, and the base's upstream remote. Then NEW-7 to NEW-9 decide as usual | ✎ |
| NEW-43 | `--from <remote>/b` | That remote too | ✚ |
| NEW-44 | A fetch fails (unreachable, no access, refused update) | Fail with git's error, before anything else happens | ✓ for `<remote>/<x>`, ✚ for an existing branch (today ignores `--fetch`) |
| NEW-45 | No fetch remote (no remotes, or several with no `origin` and no `checkout.defaultRemote`), and `x` isn't known on any remote | Fail: `no remote to fetch`, naming `gitwt new <remote>/x --fetch` for each remote, or `gitwt new x` without `--fetch`. The base's upstream remote alone doesn't count: it says where the base comes from, not where `x` lives | ✎ |
| NEW-46 | A single-branch or shallow clone, whose fetch config doesn't cover every branch | `x` (and `--from <remote>/b`) is also fetched by name from that remote, so whether it exists there is known for sure | ✎ |

### Always

| ID | Case | Result | |
|---|---|---|---|
| NEW-47 | The worktree folder is taken | Fail, saying what's using it (a branch, another repo, a plain folder) | ✓ |
| NEW-48 | `gitwt.path` is invalid | Fail before anything is created | ✓ |
| NEW-49 | `<branch>` isn't a valid branch name | Fail with git's reason, before anything is created | ✎ |
| NEW-50 | After the worktree is added | Set it up (SETUP-1 to SETUP-4), then switch to it | ✓ |

---

## `gitwt switch`

```text
gitwt switch <branch>      # alias: sw
```

`cd`s into that worktree.

| ID | Case | Result | |
|---|---|---|---|
| SW-1 | A branch with a worktree (TGT-1), the main repo included | `cd` into its top folder | ✓ |
| SW-2 | A path (TGT-4) | Fail, printing the `cd` command to use | ✎ |
| SW-3 | You're already at its top folder | Stay, and say `already at <path>` | ✎ |
| SW-4 | You're in a subfolder of it | `cd` to its top folder | ✓ |
| SW-5 | No `<branch>` | Fail with usage | ✓ |
| SW-6 | Anything else | As [`<target>`](#naming-a-worktree-target) says for a branch: fail, naming the command to use | ✎ |

---

## `gitwt remove`

```text
gitwt remove <target> [--branch] [--force]
```

Removes that worktree. `rm` is an alias. If you're inside it, you end up in the main repo, but only once removal is going ahead.

**What each flag means:**
- **`--branch`** also deletes the branch, only when none of its commits would be lost: they're all in its upstream; or, if it has no upstream or its upstream is gone, in the main repo's current branch (its HEAD commit when detached). Where you run the command doesn't matter. It's checked before anything is removed. A squash- or rebase-merged branch has commits that are in neither, so `--branch` refuses it (RM-10); `--force` deletes it.
- **`--force`** goes ahead even when something would be [lost](#words-used-here): files in the worktree, and, with `--branch`, commits that are only on that branch (RM-10a). It doesn't unlock a locked worktree. Ignored files not listed in `.worktreeinclude` aren't lost in this sense, so they go without `--force` (RM-1).

| ID | Case | Result | |
|---|---|---|---|
| RM-1 | Clean worktree | Remove it. Name any unlisted ignored files that go with it, in one line | ✓ |
| RM-2 | Uncommitted changes or untracked files | Fail, naming `--force` and what it discards | ✓ |
| RM-3 | A file listed in `.worktreeinclude` changed in the worktree, or only there | Fail, printing the `diff` or `cp` command, naming `--force` | ✓ |
| RM-4 | Initialised submodules in the worktree | Fail, naming `--force` | ✎ |
| RM-5 | `--force` | Remove it, whatever RM-2 to RM-4 would have said | ✓ |
| RM-6 | A locked worktree, with or without `--force` | Fail, naming `git worktree unlock <path>` | ✎ |
| RM-7 | The main repo, by branch or path | Fail: the main repo can't be removed | ✓ by branch, ✚ by path |
| RM-8 | You're inside it | Once removal goes ahead, you end up in the main repo, and it says so. If it fails, you stay where you were | ✓ |
| RM-9 | `--branch`, nothing would be lost | Remove the worktree, then delete the branch | ✎ |
| RM-10 | `--branch` without `--force`, the branch has commits that would be lost | Fail before removing anything: `'x' has N commits not in '<upstream or main repo's branch>'`. Name `gitwt remove x --branch --force` to delete them, or `gitwt remove x` to keep the branch | ✎ |
| RM-10a | `--branch --force`, the branch has commits that would be lost | Remove the worktree and delete the branch. Say how many commits went, and the command to get the branch back: `git branch x <sha>` | ✎ |
| RM-11 | `--branch`, detached worktree (named by path) | Fail before removing anything: there's no branch to delete. Name `gitwt remove <path>` | ✚ |
| RM-12 | A stale worktree (folder gone) | Remove git's record of that worktree only, not other stale ones. With `--branch`, as RM-9 to RM-10a | ✎ |
| RM-13 | A stale worktree that's locked (often a drive that isn't plugged in) | As RM-6 | ✎ |
| RM-14 | `--branch`, and git can't delete the branch after the worktree was removed (for example a ref lock) | Exit 1: `Error: worktree removed, but 'x' was kept: <git's reason>` | ✎ |
| RM-16 | `--branch`, and the branch has no worktree | Delete the branch by the same rules: RM-9 when nothing would be lost, RM-10 or RM-10a otherwise. So `remove x --branch` always ends with `x` gone, or fails | ✎ |
| RM-15 | Anything else | As [`<target>`](#naming-a-worktree-target) says | ✎ |

---

## `gitwt move`

```text
gitwt move <target> [<path>]      # alias: mv
```

Moves that worktree, with everything in it, as it is.

**What `<path>` means:** where it goes, like `mv`, except missing parent folders are created. It never renames the branch. An existing folder, or a path ending in `/`, means "into it, keeping the folder name". A relative path starts from your current folder. No `<path>` means "where `gitwt.path` puts this branch".

| ID | Case | Result | |
|---|---|---|---|
| MV-1 | No `<path>` | Move it to where `gitwt.path` puts the branch | ✓ |
| MV-2 | `<path>` is an existing folder, or ends in `/` | Move it inside, keeping its folder name | ✓ |
| MV-3 | Otherwise | Move it to exactly `<path>`, creating missing parent folders | ✓ |
| MV-4 | It's already there | Succeed and say `already at <path>`; nothing changes | ✓ |
| MV-5 | You're inside it | You move with it, to the same subfolder | ✓ |
| MV-6 | After any move | Note that tools that saved the old full path may need recreating | ✓ |
| MV-7 | The new place is inside the main repo or another worktree, and not ignored there | Move it, then say it shows as untracked there, with the `.git/info/exclude` line | ✓ |
| MV-8 | Destination exists | Fail. Without `<path>`, say what's using it | ✓ |
| MV-9 | Destination inside the worktree, or a file where a folder must be | Fail | ✓ |
| MV-10 | Locked, on another drive, or contains submodules | Fail, naming the way out (unlock; or remove and `git worktree add` there) | ✓ |
| MV-11 | The main repo, by branch or path | Fail: the main repo can't be moved | ✓ by branch, ✚ by path |
| MV-12 | A detached worktree, no `<path>` | Fail: there's no branch for `gitwt.path` to place. Name `gitwt move <its path> <new path>` | ✚ |
| MV-13 | A failed move | Parent folders it created are removed again | ✓ |
| MV-14 | Anything else | As [`<target>`](#naming-a-worktree-target) says | ✎ |

---

## `gitwt list`

```text
gitwt list [-l | -s]      # alias: ls
```

Shows every worktree from git's own records. No network.

| ID | Case | Result | |
|---|---|---|---|
| LS-1 | No flag | BRANCH, SYNC (vs upstream, as of the last fetch), LAST COMMIT, PATH; `*` on the one you're in | ✓ |
| LS-2 | `-l` / `--long` | Adds CHANGES (reads every worktree's files) | ✓ |
| LS-3 | `-s` / `--short` | Branch and path only, no header | ✓ |
| LS-4 | `-l` and `-s` together | Fail: pick one | ✎ |
| LS-5 | PATH | Relative to the folder that contains the main repo, or the full path when it's elsewhere. It's for reading; to name a worktree by path, use its full path | ✓ |
| LS-6 | A stale worktree | Shows `(stale)`, and ends with a tip naming `gitwt remove <branch or old path>` for each | ✎ |
| LS-7 | A detached worktree | Shows `(detached:<sha>)` | ✓ |
| LS-8 | A bare main repo | Shows `(bare)` | ✓ |
| LS-9 | A locked worktree | Shows `(locked)` | ✓ |

---

## `gitwt version` and `gitwt help`

| ID | Case | Result | |
|---|---|---|---|
| VH-1 | `gitwt version`, `-v`, `--version` | Print the version | ✓ |
| VH-2 | `gitwt help`, `-h`, `--help`, or `gitwt` alone | Print the command summary | ✓ |
| VH-3 | `gitwt help <command>` | Print that command's usage, the same as `gitwt <command> --help` (ALL-7). An alias (`rm`, `sw`, `mv`, `ls`) gives its command's usage; an unknown command fails as ALL-9 | ✚ |
| VH-4 | Any other extra argument | Fail with usage | ✎ |

---

## Setting up new worktrees

Runs after `gitwt new` adds a worktree (NEW-50), never otherwise.

| ID | Case | Result | |
|---|---|---|---|
| SETUP-1 | `.worktreeinclude` in the main repo | Copy the listed, ignored files from the main repo; never overwrite. A file that can't be copied: warn, carry on, keep the worktree, exit 1 at the end with `Error: worktree added, but N files weren't copied` | ✓ |
| SETUP-2 | A setup script that isn't approved, with a terminal | Ask once whether to run it and remember that version. The only question gitwt asks. Declining skips it and exits 0 | ✓ |
| SETUP-3 | A setup script that isn't approved, no terminal | Skip it, printing the exact `git config gitwt.postCreateApproved <hash>` command to approve this version, and how to run it by hand in the worktree. Exit 0 | ✎ |
| SETUP-4 | The setup script fails | Keep the worktree, switch to it, exit 1 | ✓ |

---

## Zsh tab-completion

| ID | Typed | Offers | |
|---|---|---|---|
| CMP-1 | `gitwt <Tab>` | Commands and their aliases (`sw`, `rm`, `mv`, `ls`) | ✎ |
| CMP-2 | `gitwt new <Tab>` | Local branches without a worktree, `--from`, `--fetch`, and one `<remote>/` per remote | ✎ |
| CMP-3 | `gitwt new origin/<Tab>` | `origin`'s branches with no local branch of that name, one path part at a time | ✚ |
| CMP-4 | `gitwt new x --from <Tab>` | Local branches and one `<remote>/` per remote; after `origin/`, its branches. Not tags | ✎ |
| CMP-5 | `gitwt switch <Tab>` | Branches with a worktree | ✓ |
| CMP-6 | `gitwt remove <Tab>` | Branches with a worktree, except the main repo's; `--branch`, `--force` | ✎ |
| CMP-7 | `gitwt move <Tab>` | Branches with a worktree, except the main repo's; then folders | ✓ |
| CMP-8 | `gitwt list <Tab>` | `-l`, `--long`, `-s`, `--short` | ✓ |
| CMP-9 | `gitwt remove ./<Tab>` (also `move`) | Worktree folders. `switch` offers none | ✚ |

Completion never offers bare remote branch names: type `ori<Tab>` for `origin/`, then the path.

---

## Not covered

- **`git worktree add` itself can use the network** in a partial (blobless) clone or with Git LFS, even without `--fetch`. That's git, not gitwt.
- **Bare main repos** (the `git clone --bare` layout): `list` shows them (LS-8), but what `switch`, `remove` and `move` do with the bare repo isn't settled yet.
- **A worktree picker** for `gitwt sw` with no target (TASK-035) would ask a question, so it needs Principle 2 amended when it's built.
- **bash tab-completion** doesn't exist yet ([issue #11](https://github.com/ashikahmad/gitwt/issues/11)).

---

## Decisions

| ID | Question | Answer |
|---|---|---|
| Q1 | `new x --fetch` when, after the fetch, `x` is on no remote: new branch, or fail? | **Decided:** new branch (NEW-33). To require the remote branch, write `origin/x` (NEW-13) |
| Q2 | `--fetch` with a local base that's behind its upstream: start from the upstream (NEW-33), or fail and name `--from origin/b`? | **Decided:** start from the upstream. Asking for a fetch means asking for the latest. The same applies to an existing branch (NEW-4): it's fast-forwarded, and if it's checked out somewhere, gitwt fails for safety, so you're never left in a worktree that looks current but isn't rather than move it |
| Q3 | Should `switch`, `remove` and `move` accept a worktree's path (TGT-2 to TGT-5, TGT-11, SW-2, RM-11, MV-12, CMP-9)? It's the only way to name a detached worktree | **Decided:** `remove` and `move` yes, top folder only, so a path inside one can't remove or move it by accident. `switch` no: `cd <path>` does the same, shorter and clearer |
| Q4 | `remove x --branch --force` with commits that would be lost: delete it too, or still fail (RM-10)? | **Decided:** delete it (RM-10a). The user asked for the branch gone and forced it. gitwt says what was lost and how to get it back |
| Q5 | `remove` on a stale worktree: remove git's record (RM-12), or fail naming `git worktree prune` (today)? | **Decided:** remove that one record. The user asked for it gone, and the folder is already gone. `git worktree prune` would also prune other entries. A locked one still fails (RM-13) |
| Q6 | `gitwt help <command>`: print that command's usage (VH-3), or fail as an extra argument? | **Decided:** print it, the same as `gitwt <command> --help` (ALL-7) |
| Q7 | A local branch literally named `origin/x` while `origin/x` is also a remote branch (NEW-22): fail, or prefer the local branch? | **Decided:** prefer the local branch everywhere, as git does, and say so in `new` and `--from`, naming the rename that reaches the remote's branch |
| Q8 | `gitwt rm` (today it prints help): add `rm` as an alias of `remove`, like `sw`, `mv` and `ls`, or only suggest `remove` (ALL-9)? | **Decided:** add the alias |
| Q9 | `remove x --branch` on a squash- or rebase-merged branch, whose commits are in neither its upstream nor the main repo's current branch | **Decided:** refuse (RM-10); `--force` deletes it. Detecting squash merges would be guessing |
| Q10 | `new x` on a stale worktree (NEW-2): fail naming `gitwt remove x`, or drop the record and re-add? | **Decided:** drop and re-add. You asked for a worktree, the old one can't be used, and dropping the record is the step RM-12 already treats as safe |
| Q11 | `switch origin/x` (TGT-8): accept it when local `x` tracks `origin/x`? | **Decided:** no. `switch` doesn't deal in remotes; the error names `gitwt switch x` |
| Q12 | A PATH copied from `list` (relative, like `gitwt-x`) used as a `<target>` (TGT-9) | **Decided:** `list` keeps its short paths; the error spots the match and names the full path |
| Q13 | `remove x --branch` when `x` has no worktree (TGT-6): name `git branch -d x`, or delete it by gitwt's own rule? | **Decided:** gitwt's rule (RM-16), so `remove x --branch` means one thing: `x` is gone |

---

## Delivery

One PR per command, each with a test per case ID, and the guide updated for that command. Later PRs build on the helpers earlier ones add.

1. **Everywhere + `switch`:** argument checking (ALL), `<target>` (TGT), SW. This adds the shared helpers.
2. **`remove`** (RM), on top of 1.
3. **`move`** (MV), on top of 1.
4. **`list`, `version`, `help`** (LS, VH), on top of 1.
5. **`new`**, split if it's too large to review in one: local and new branches with `--from` (NEW-1 to 3, 6, 25 to 31a, 47 to 50); then remote branches and `--fetch` (NEW-4, 4a, 5, 7 to 24, 32 to 46), reworking PR #13. Setup (SETUP-3) and completion (CMP) go with the command they belong to.

### How this spec is reviewed

Before it's final, every case is checked for:
- **The principles:** does it follow all five?
- **The user's reading:** would someone typing this command expect exactly this result? If they'd more likely have meant something else, or would have typed something more obvious for this result, the case is wrong.
- **Completeness:** is there a combination of parameters and repo state no case covers?
- **Agreement:** do two cases contradict each other, or does the same word mean different things in two commands?
