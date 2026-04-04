#!/usr/bin/env bash
# gitwt - A friendly git worktree CLI wrapper
# Source this file in your .bashrc or .zshrc:
#   source ~/.config/gitwt/gitwt.sh

gitwt() {
  local cmd="${1:-help}"

  case "$cmd" in
    new)       _gitwt_new    "${@:2}" ;;
    add)       _gitwt_add    "${@:2}" ;;
    remove)    _gitwt_remove "${@:2}" ;;
    switch|sw) _gitwt_switch "${@:2}" ;;
    list|ls)   _gitwt_list ;;
    help|*)    _gitwt_help ;;
  esac
}

# ── helpers ────────────────────────────────────────────────────────────────────

_gitwt_main_repo_root() {
  # Always returns the main repo root, whether called from main or a worktree
  git worktree list --porcelain 2>/dev/null \
    | awk 'NR==1 { sub(/^worktree /, ""); print; exit }'
}

# Used only by `add` — generates the conventional target path for new worktrees
_gitwt_generate_path() {
  local branch="$1"   # e.g. fix/checkin-timeout-issue-103

  local main_root
  main_root="$(_gitwt_main_repo_root)" || { echo "Error: not inside a git repo." >&2; return 1; }

  local repo_name
  repo_name="$(basename "$main_root")"

  local slug
  if [[ "$branch" == */* ]]; then
    local type rest
    type="${branch%%/*}"
    rest="${branch#*/}"
    slug="${type}-${rest}"
  else
    slug="$branch"
  fi

  echo "$(dirname "$main_root")/worktrees/${repo_name}/${slug}"
}

# Used by `switch` and `remove` — looks up the actual registered path by branch name
_gitwt_find_path() {
  local branch="$1"

  local found
  found="$(git worktree list --porcelain | awk -v target="$branch" '
    /^worktree / { path = substr($0, 10) }
    /^branch /   { branch = substr($0, 8); sub(/^refs\/heads\//, "", branch) }
    /^$/          {
      if (branch == target) { print path; exit }
      path = ""; branch = ""
    }
  ')"

  if [[ -z "$found" ]]; then
    echo "Error: no worktree found for branch '$branch'." >&2
    echo "Tip: run 'gitwt list' to see all registered worktrees." >&2
    return 1
  fi

  echo "$found"
}

# ── subcommands ────────────────────────────────────────────────────────────────

_gitwt_new() {
  local branch="" from_branch="" do_pull=0

  # Parse args — accept --pull and --from <branch> anywhere
  local arg
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --pull)  do_pull=1 ; shift ;;
      --from)  from_branch="$2" ; shift 2 ;;
      --from=*) from_branch="${1#--from=}" ; shift ;;
      *)       branch="$1" ; shift ;;
    esac
  done

  if [[ -z "$branch" ]]; then
    echo "Usage: gitwt new <type/branch-name> [--from <base-branch>] [--pull]" >&2
    echo "Example: gitwt new feature/dark-mode --from develop" >&2
    return 1
  fi

  # Determine base branch — explicit --from or current branch
  local base_branch
  if [[ -n "$from_branch" ]]; then
    # Validate the given base branch exists
    if ! git show-ref --verify --quiet "refs/heads/$from_branch"; then
      echo "Error: base branch '$from_branch' does not exist locally." >&2
      return 1
    fi
    base_branch="$from_branch"
  else
    base_branch="$(git symbolic-ref --short HEAD 2>/dev/null)"
    if [[ -z "$base_branch" ]]; then
      echo "Error: could not determine current branch (are you in detached HEAD state?)" >&2
      return 1
    fi
  fi

  # Optionally pull the base branch first
  if (( do_pull )); then
    echo "Pulling '$base_branch'..."
    # If base branch isn't current, switch to it temporarily in the main repo
    local current_branch
    current_branch="$(git symbolic-ref --short HEAD 2>/dev/null)"
    if [[ "$base_branch" != "$current_branch" ]]; then
      local main_root
      main_root="$(_gitwt_main_repo_root)"
      git -C "$main_root" fetch origin "$base_branch:$base_branch" \
        || { echo "Error: could not fetch '$base_branch'." >&2; return 1; }
    else
      git pull || { echo "Error: git pull failed." >&2; return 1; }
    fi
  fi

  # Refuse if the new branch already exists
  if git show-ref --verify --quiet "refs/heads/$branch"; then
    echo "Error: branch '$branch' already exists. Use 'gitwt add $branch' instead." >&2
    return 1
  fi

  local worktree_path
  worktree_path="$(_gitwt_generate_path "$branch")" || return 1

  if [[ -d "$worktree_path" ]]; then
    echo "Error: worktree path already exists: $worktree_path" >&2
    return 1
  fi

  echo "Creating '$branch' from '$base_branch' at: $worktree_path"
  if git worktree add -b "$branch" "$worktree_path" "$base_branch"; then
    echo "Done! Switching into it now..."
    cd "$worktree_path" || return 1
  else
    return 1
  fi
}

_gitwt_add() {
  local branch="$1"
  if [[ -z "$branch" ]]; then
    echo "Usage: gitwt add <type/branch-name>" >&2
    echo "Example: gitwt add fix/checkin-timeout-issue-103" >&2
    return 1
  fi

  local worktree_path
  worktree_path="$(_gitwt_generate_path "$branch")" || return 1

  if [[ -d "$worktree_path" ]]; then
    echo "Error: worktree path already exists: $worktree_path" >&2
    return 1
  fi

  # Check if branch already exists locally
  local git_cmd
  if git show-ref --verify --quiet "refs/heads/$branch"; then
    git_cmd=(git worktree add "$worktree_path" "$branch")
  else
    git_cmd=(git worktree add -b "$branch" "$worktree_path")
  fi

  echo "Creating worktree at: $worktree_path"
  if "${git_cmd[@]}"; then
    echo "Done! Switch to it with:"
    echo "  gitwt sw $branch"
  else
    return 1
  fi
}

_gitwt_switch() {
  local branch="$1"
  if [[ -z "$branch" ]]; then
    echo "Usage: gitwt switch <type/branch-name>" >&2
    echo "Example: gitwt switch fix/checkin-timeout-issue-103" >&2
    return 1
  fi

  local worktree_path
  worktree_path="$(_gitwt_find_path "$branch")" || return 1

  echo "Switching to worktree: $worktree_path"
  cd "$worktree_path" || return 1
}

_gitwt_remove() {
  local branch="$1"
  if [[ -z "$branch" ]]; then
    echo "Usage: gitwt remove <type/branch-name>" >&2
    echo "Example: gitwt remove fix/checkin-timeout-issue-103" >&2
    return 1
  fi

  local worktree_path
  worktree_path="$(_gitwt_find_path "$branch")" || return 1

  local current_dir
  current_dir="$(pwd)"

  # If we're inside the worktree, jump back to main repo first
  local main_root
  main_root="$(_gitwt_main_repo_root)"
  if [[ "$current_dir" == "$worktree_path"* ]]; then
    echo "Currently inside worktree — returning to main repo: $main_root"
    cd "$main_root" || return 1
  fi

  echo "Removing worktree: $worktree_path"
  if git worktree remove "$worktree_path"; then
    echo "Worktree removed."
  else
    echo "Tip: if there are uncommitted changes, use: git worktree remove --force $worktree_path" >&2
    return 1
  fi
}

_gitwt_list() {
  local main_root
  main_root="$(_gitwt_main_repo_root 2>/dev/null)"
  if [[ -z "$main_root" ]]; then
    echo "Error: not inside a git repo." >&2
    return 1
  fi

  local parent_of_main
  parent_of_main="$(dirname "$main_root")"

  printf "%-40s %s\n" "BRANCH" "PATH"
  printf "%-40s %s\n" "──────────────────────────────────────" "──────────────────────────────────────"

  git worktree list --porcelain | awk -v base="$parent_of_main" '
    /^worktree / { path = substr($0, 10) }
    /^branch /   { branch = substr($0, 8); sub(/^refs\/heads\//, "", branch) }
    /^$/          {
      if (path != "" && branch != "") {
        rel = path
        if (index(path, base "/") == 1)
          rel = substr(path, length(base) + 2)
        printf "%-40s %s\n", branch, rel
      }
      path = ""; branch = ""
    }
  '
}

_gitwt_help() {
  cat <<'EOF'
gitwt — a friendly wrapper around git worktree

USAGE
  gitwt <command> [args]

COMMANDS
  new <type/branch-name>      Branch off the current branch (or --from <base>),
                              create a worktree, and cd into it immediately.
                              Flags:
                                --from <base>   branch off <base> instead of current
                                --pull          pull the base branch first

  add <type/branch-name>      Create a new worktree at the conventional path:
                                ../worktrees/<repoName>/<type>-<branch-name>

  switch <type/branch-name>   cd into an existing worktree (looked up from git,
                              so works for any worktree, not just ones gitwt created).
                              Alias: sw

  remove <type/branch-name>   Remove a worktree (looked up from git). If your shell
                              is currently inside it, you'll be cd'd back to the
                              main repo automatically.

  list                        List all worktrees as "branch  relativePath".
                              Alias: ls

  help                        Show this message.

WORKTREE PATH LAYOUT (for `add`)
  New worktrees are placed at:
    ../worktrees/<repoName>/<type>-<branch-name>

  Examples:
    gitwt add fix/checkin-timeout-issue-103
    → ../worktrees/awesomeRepo/fix-checkin-timeout-issue-103

    gitwt add feature/dark-mode
    → ../worktrees/awesomeRepo/feature-dark-mode

TYPICAL WORKFLOW
    gitwt ls                              # see all worktrees
    gitwt new feature/dark-mode                     # branch off current + worktree + cd in
    gitwt new feature/dark-mode --from develop       # branch off develop instead
    gitwt new feature/dark-mode --from main --pull   # pull main first, then branch off it
    gitwt add feature/dark-mode           # worktree for an existing branch
    gitwt sw feature/dark-mode            # jump into an existing worktree
    gitwt sw main                         # jump to any branch, even manually added ones
    gitwt remove feature/dark-mode        # done — jumps back to main repo if needed

INSTALL
  1. Place this file somewhere permanent, e.g.:
       mkdir -p ~/.config/gitwt
       cp gitwt.sh ~/.config/gitwt/gitwt.sh

  2. Add to your ~/.bashrc or ~/.zshrc:
       source ~/.config/gitwt/gitwt.sh

  3. Reload your shell:
       source ~/.bashrc   # or source ~/.zshrc
EOF
}
