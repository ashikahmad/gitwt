#!/usr/bin/env bash
# gitwt - A friendly git worktree CLI wrapper
# Source this file in your .zshrc or .bashrc:
#   source ~/.config/gitwt/gitwt.sh

gitwt() {
  local cmd="${1:-help}"
  local GITWT_VERSION="0.1.0"

  case "$cmd" in
    new)               _gitwt_new    "${@:2}" ;;
    remove)            _gitwt_remove "${@:2}" ;;
    switch|sw)         _gitwt_switch "${@:2}" ;;
    list|ls)           _gitwt_list ;;
    version|--version|-v) echo "gitwt $GITWT_VERSION" ;;
    help|*)            _gitwt_help ;;
  esac
}

# ── helpers ────────────────────────────────────────────────────────────────────

_gitwt_main_repo_root() {
  # Always returns the main repo root, whether called from main or a worktree
  git worktree list --porcelain 2>/dev/null \
    | awk 'NR==1 { sub(/^worktree /, ""); print; exit }'
}

# Generates the conventional target path for new worktrees
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
    slug="${type}-${rest//\//-}"
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

  if [[ ! -d "$found" ]]; then
    echo "Error: worktree path no longer exists: $found" >&2
    echo "Tip: run 'git worktree prune' to clean up stale entries." >&2
    return 1
  fi

  echo "$found"
}

# ── subcommands ────────────────────────────────────────────────────────────────

_gitwt_new() {
  local branch="" from_branch="" do_fetch=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --fetch)  do_fetch=1 ; shift ;;
      --from)   from_branch="$2" ; shift 2 ;;
      --from=*) from_branch="${1#--from=}" ; shift ;;
      *)        branch="$1" ; shift ;;
    esac
  done

  if [[ -z "$branch" ]]; then
    echo "Usage: gitwt new <branch-name> [--from <base>] [--fetch]" >&2
    echo "Example: gitwt new feature/dark-mode --from develop" >&2
    return 1
  fi

  # If branch already has a worktree, suggest switch
  if git worktree list --porcelain 2>/dev/null | awk '/^branch / { sub(/^refs\/heads\//, "", $2); print $2 }' | grep -qxF "$branch"; then
    echo "Error: branch '$branch' already has a worktree. Use 'gitwt switch $branch' instead." >&2
    return 1
  fi

  local worktree_path
  worktree_path="$(_gitwt_generate_path "$branch")" || return 1

  if [[ -d "$worktree_path" ]]; then
    echo "Error: worktree path already exists: $worktree_path" >&2
    echo "Tip: run 'gitwt list' to see all registered worktrees." >&2
    return 1
  fi

  # Branch already exists locally — just attach a worktree, no branch creation
  if git show-ref --verify --quiet "refs/heads/$branch"; then
    if [[ -n "$from_branch" || "$do_fetch" -eq 1 ]]; then
      echo "Note: --from and --fetch are ignored when the branch already exists." >&2
    fi
    echo "Branch '$branch' exists — creating worktree at: $worktree_path"
    if git worktree add "$worktree_path" "$branch"; then
      echo "Done! Switching into it now..."
      cd "$worktree_path" || return 1
    else
      return 1
    fi
    return 0
  fi

  # Branch does not exist — create it from a base branch
  local base_branch
  if [[ -n "$from_branch" ]]; then
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

  if (( do_fetch )); then
    local remote
    remote="$(git config "branch.${base_branch}.remote" 2>/dev/null || echo "origin")"
    local remote_ref="$remote/$base_branch"

    echo "Fetching '$base_branch' from '$remote'..."
    if ! git fetch "$remote" "$base_branch"; then
      echo "Error: could not fetch '$base_branch' from '$remote'." >&2
      return 1
    fi

    if git rev-parse --verify "$remote_ref" &>/dev/null; then
      local ahead behind
      ahead="$(git rev-list --count "${remote_ref}..${base_branch}")"
      behind="$(git rev-list --count "${base_branch}..${remote_ref}")"

      if (( ahead == 0 && behind == 0 )); then
        echo "'$base_branch' is already up to date."
      elif (( ahead == 0 )); then
        echo "'$base_branch' is $behind commit(s) behind remote — branching from remote."
        base_branch="$remote_ref"
      elif (( behind == 0 )); then
        echo "'$base_branch' is $ahead commit(s) ahead of remote — using local."
      else
        printf "\n  '%s' has diverged from '%s':\n" "$base_branch" "$remote_ref"
        printf "    Local:  %s commit(s) ahead\n" "$ahead"
        printf "    Remote: %s commit(s) ahead\n\n" "$behind"
        printf "  1) Branch off %s (latest remote state)\n" "$remote_ref"
        printf "  2) Branch off local %s\n" "$base_branch"
        printf "  3) Abort\n"
        printf "  Choice [1-3]: "
        local choice
        read -r choice
        case "$choice" in
          1) base_branch="$remote_ref" ;;
          2) ;;
          *) echo "Aborted." >&2; return 1 ;;
        esac
      fi
    fi
  fi

  echo "Creating '$branch' from '$base_branch' at: $worktree_path"
  if git worktree add -b "$branch" "$worktree_path" "$base_branch"; then
    echo "Done! Switching into it now..."
    cd "$worktree_path" || return 1
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
  local branch="" delete_branch=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --branch) delete_branch=1 ; shift ;;
      *)        branch="$1" ; shift ;;
    esac
  done

  if [[ -z "$branch" ]]; then
    echo "Usage: gitwt remove <type/branch-name> [--branch]" >&2
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
  if ! git worktree remove "$worktree_path"; then
    echo "Tip: if there are uncommitted changes, use: git worktree remove --force $worktree_path" >&2
    return 1
  fi
  echo "Worktree removed."

  if (( delete_branch )); then
    if git branch -d "$branch"; then
      echo "Branch '$branch' deleted."
    else
      echo "Tip: branch has unmerged commits — use 'git branch -D $branch' to force delete." >&2
    fi
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

  printf "%-40s %-26s %-30s %s\n" "BRANCH" "SYNC" "CHANGES" "PATH"
  printf "%-40s %-26s %-30s %s\n" \
    "──────────────────────────────────────" \
    "────────────────────────" \
    "────────────────────────────" \
    "──────────────────────────────────────"

  local wt_path="" branch="" head="" is_detached="" stale=0
  while IFS= read -r line; do
    case "$line" in
      "worktree "*) wt_path="${line#worktree }" ;;
      "HEAD "*)     head="${line#HEAD }" ;;
      "branch "*)   branch="${line#branch }"; branch="${branch#refs/heads/}" ;;
      "detached")   is_detached=1 ;;
      "")
        if [[ -n "$wt_path" ]]; then
          if [[ ! -d "$wt_path" ]]; then
            local rel="$wt_path"
            [[ "$wt_path" == "$parent_of_main/"* ]] && rel="${wt_path#$parent_of_main/}"
            printf "%-40s %-26s %-30s %s\n" "(stale)" "-" "-" "$rel"
            wt_path=""; branch=""; head=""; is_detached=""
            stale=1
            continue
          fi

          local display_branch="${branch:-(detached:${head:0:7})}"

          local rel="$wt_path"
          [[ "$wt_path" == "$parent_of_main/"* ]] && rel="${wt_path#$parent_of_main/}"

          # SYNC — ahead/behind vs upstream (skip for detached HEAD)
          local sync="-"
          if [[ -z "$is_detached" && -n "$branch" ]]; then
            local ahead="$(git -C "$wt_path" rev-list --count "@{u}..HEAD" 2>/dev/null)"
            local behind="$(git -C "$wt_path" rev-list --count "HEAD..@{u}" 2>/dev/null)"
            if [[ -n "$ahead" && -n "$behind" ]]; then
              if (( ahead == 0 && behind == 0 )); then
                sync="clean"
              else
                sync=""
                (( ahead  > 0 )) && sync="${sync:+$sync · }${ahead} ahead"
                (( behind > 0 )) && sync="${sync:+$sync · }${behind} behind"
              fi
            fi
          fi

          # CHANGES — staged / modified / untracked
          local staged=0 modified=0 untracked=0
          while IFS= read -r sline; do
            local x="${sline:0:1}" y="${sline:1:1}"
            if [[ "$x" == "?" && "$y" == "?" ]]; then
              (( untracked++ ))
            else
              [[ "$x" != " " ]] && (( staged++ ))
              [[ "$y" == "M" || "$y" == "D" ]] && (( modified++ ))
            fi
          done < <(git -C "$wt_path" status --porcelain 2>/dev/null)

          local changes=""
          (( staged    > 0 )) && changes="${changes:+$changes · }${staged} staged"
          (( modified  > 0 )) && changes="${changes:+$changes · }${modified} modified"
          (( untracked > 0 )) && changes="${changes:+$changes · }${untracked} untracked"
          [[ -z "$changes" ]] && changes="clean"

          printf "%-40s %-26s %-30s %s\n" "$display_branch" "$sync" "$changes" "$rel"
        fi
        wt_path=""; branch=""; head=""; is_detached=""
        ;;
    esac
  done < <(git worktree list --porcelain)

  (( stale )) && echo "" && echo "Tip: stale entries detected — run 'git worktree prune' to clean up."
}

_gitwt_help() {
  cat <<'EOF'
gitwt — a friendly wrapper around git worktree

USAGE
  gitwt <command> [args]

COMMANDS
  new <branch-name>           Create a worktree and cd into it immediately.
                              If the branch already exists locally, just attaches
                              a worktree. If not, creates the branch first.
                              Flags (only apply when creating a new branch):
                                --from <base>   branch off <base> instead of current
                                --fetch         fetch the base branch first; if diverged,
                                                asks whether to branch from remote or local

  switch <branch-name>        cd into an existing worktree (looked up from git,
                              so works for any worktree, not just ones gitwt created).
                              Alias: sw

  remove <branch-name>        Remove a worktree (looked up from git). If your shell
                              is currently inside it, you'll be cd'd back to the
                              main repo automatically.
                              Flags:
                                --branch        also delete the local branch

  list                        Show all worktrees with branch, sync state
                              (ahead/behind upstream), changes, and path.
                              Alias: ls

  version                     Show the current gitwt version.
                              Also: gitwt --version, gitwt -v

  help                        Show this message.

WORKTREE PATH LAYOUT
  New worktrees are placed at:
    ../worktrees/<repoName>/<type>-<branch-name>

  Examples:
    gitwt new fix/checkin-timeout-issue-103
    → ../worktrees/awesomeRepo/fix-checkin-timeout-issue-103

    gitwt new feature/dark-mode
    → ../worktrees/awesomeRepo/feature-dark-mode

TYPICAL WORKFLOW
    gitwt ls                                        # see all worktrees
    gitwt new feature/dark-mode                     # new branch off current + worktree + cd in
    gitwt new feature/dark-mode --from develop      # branch off develop instead
    gitwt new feature/dark-mode --from main --fetch # fetch main first, then branch off it
    gitwt new fix/existing-branch                   # existing branch — just attach worktree
    gitwt sw feature/dark-mode                      # jump into an existing worktree
    gitwt sw main                                   # jump to any branch
    gitwt remove feature/dark-mode                  # done — jumps back to main repo if needed

INSTALL
  1. Place this file somewhere permanent, e.g.:
       mkdir -p ~/.config/gitwt
       cp gitwt.sh ~/.config/gitwt/gitwt.sh

  2. Add to your ~/.zshrc or ~/.bashrc:
       source ~/.config/gitwt/gitwt.sh

  3. Reload your shell:
       source ~/.zshrc   # or source ~/.bashrc
EOF
}
