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
    move|mv)           _gitwt_move   "${@:2}" ;;
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

# Flattens a branch name into one folder name, e.g. fix/a/b → fix-a-b
_gitwt_branch_slug() {
  echo "${1//\//-}"
}

# Resolves ".", ".." and repeated or trailing slashes in an absolute path,
# without touching the filesystem (the path usually doesn't exist yet)
_gitwt_normalize_path() {
  printf '%s\n' "$1" | awk '{
    n = split($0, parts, "/")
    depth = 0
    for (i = 1; i <= n; i++) {
      if (parts[i] == "" || parts[i] == ".") continue
      if (parts[i] == "..") { if (depth > 0) depth--; continue }
      stack[++depth] = parts[i]
    }
    out = ""
    for (i = 1; i <= depth; i++) out = out "/" stack[i]
    print (out == "" ? "/" : out)
  }'
}

# Generates the target path for new worktrees from the `gitwt.path` git config
# template, falling back to the default layout when it isn't set
_gitwt_generate_path() {
  local branch="$1"   # e.g. fix/checkin-timeout-issue-103

  local main_root
  main_root="$(_gitwt_main_repo_root)" || { echo "Error: not inside a git repo." >&2; return 1; }

  # --type=path expands a leading ~; exit status 1 means the key isn't set
  local template rc=0
  template="$(git config --type=path --get gitwt.path 2>/dev/null)" || rc=$?
  if (( rc == 1 )); then
    template="../worktrees/{repo}/{slug}"
  elif (( rc != 0 )); then
    echo "Error: could not read gitwt.path. Check its value with: git config --get gitwt.path" >&2
    return 1
  fi

  # Git doesn't expand shell variables, so '$HOME/wts' would become a folder named '$HOME'
  if [[ "$template" == *'$'* ]]; then
    echo "Error: gitwt.path can't use shell variables such as \$HOME: '$template'. Use ~ for your home folder, or write the full path." >&2
    return 1
  fi

  if [[ "$template" != *\{slug\}* && "$template" != *\{branch\}* ]]; then
    echo "Error: gitwt.path must contain {slug} or {branch}, otherwise every worktree gets the same path: '$template'" >&2
    return 1
  fi

  local leftover="$template"
  leftover=${leftover//\{repo\}/}
  leftover=${leftover//\{slug\}/}
  leftover=${leftover//\{branch\}/}
  if [[ "$leftover" == *\{*\}* ]]; then
    echo "Error: gitwt.path has an unknown placeholder: '$template'. Available: {repo}, {slug}, {branch}" >&2
    return 1
  fi

  local repo_name slug
  repo_name="$(basename "$main_root")"
  slug="$(_gitwt_branch_slug "$branch")"

  local resolved="$template"
  resolved=${resolved//\{repo\}/"$repo_name"}
  resolved=${resolved//\{slug\}/"$slug"}
  resolved=${resolved//\{branch\}/"$branch"}

  [[ "$resolved" == /* ]] || resolved="$main_root/$resolved"
  _gitwt_normalize_path "$resolved"
}

# A worktree inside the main repo shows up there as untracked unless it's ignored
_gitwt_note_if_untracked_in_repo() {
  local worktree_path="$1"

  local main_root
  main_root="$(_gitwt_main_repo_root)"
  [[ "$worktree_path" == "$main_root/"* ]] || return 0
  git -C "$main_root" check-ignore -q "$worktree_path" && return 0

  local rel="${worktree_path#"$main_root/"}"
  echo "Note: $rel is inside the main repo and not ignored, so it shows as untracked there." >&2
  echo "To hide it on this machine, run in the main repo: echo '${rel%%/*}/' >> .git/info/exclude" >&2
}

# Prints the branch checked out at a registered worktree path (empty if detached).
# Returns 1 if this repo has no worktree at that path.
_gitwt_worktree_owner() {
  local target="$1" line wt=""

  while IFS= read -r line; do
    case "$line" in
      "worktree "*) wt="${line#worktree }" ;;
      "branch "*)   [[ "$wt" == "$target" ]] && { echo "${line#branch refs/heads/}"; return 0; } ;;
      "detached")   [[ "$wt" == "$target" ]] && return 0 ;;
    esac
  done < <(git worktree list --porcelain)

  return 1
}

# Says what already occupies the path a new worktree needs
_gitwt_explain_existing_path() {
  local branch="$1" worktree_path="$2"

  echo "Error: worktree path already exists: $worktree_path" >&2

  # git records physical paths, and the configured path may go through a symlink
  local physical owner
  physical="$(cd "$worktree_path" && pwd -P)"

  if owner="$(_gitwt_worktree_owner "$physical")"; then
    if [[ -n "$owner" ]]; then
      echo "It belongs to branch '$owner', and '$branch' maps to the same folder." >&2
      echo "Tip: rename one of the branches, or keep slashes in folder names by using {branch} in gitwt.path." >&2
    else
      echo "It's a worktree with a detached HEAD, and '$branch' maps to the same folder." >&2
      echo "Tip: remove it with 'git worktree remove $worktree_path', or rename '$branch'." >&2
    fi
    return 0
  fi

  if [[ -e "$worktree_path/.git" ]]; then
    local other_repo
    other_repo="$(cd "$worktree_path" && _gitwt_main_repo_root)"
    if [[ -n "$other_repo" ]]; then
      echo "It's a checkout of another repo: $other_repo" >&2
      echo "Tip: repos with the same folder name, or a gitwt.path without {repo}, map to the same place. Set a different gitwt.path in one of them." >&2
      return 0
    fi
  fi

  echo "It isn't a worktree of this repo." >&2
  echo "Tip: move it out of the way, or run 'gitwt list' to see all registered worktrees." >&2
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

# Prints the files in <dir> that a .worktreeinclude lists and git ignores, NUL-separated.
# The list is <dir>/.worktreeinclude, or <include-file> when given.
_gitwt_included_files() {
  local dir="$1" include="${2:-$1/.worktreeinclude}"
  [[ -f "$include" ]] || return 0
  git -C "$dir" ls-files -z --others --ignored --exclude-from="$include" 2>/dev/null \
    | git -C "$dir" check-ignore -z --stdin 2>/dev/null
  return 0
}

# Copies the included files from <source> to <dest>. Anything already at <dest> is left alone.
# Returns non-zero if any file could not be copied.
_gitwt_copy_included() {
  local source_dir="$1" dest_dir="$2" file copied=0 skipped=0 failed=0

  while IFS= read -r -d '' file; do
    if [[ -e "$dest_dir/$file" || -L "$dest_dir/$file" ]]; then
      skipped=$((skipped + 1))
    elif mkdir -p "$(dirname "$dest_dir/$file")" && cp -Pp "$source_dir/$file" "$dest_dir/$file"; then
      copied=$((copied + 1))
    else
      echo "Warning: could not copy '$file'." >&2
      failed=$((failed + 1))
    fi
  done < <(_gitwt_included_files "$source_dir")

  (( copied > 0 ))  && echo "Copied $copied file(s) listed in .worktreeinclude."
  (( skipped > 0 )) && echo "Skipped $skipped listed file(s) already there."
  if (( failed > 0 )); then
    echo "Warning: could not copy $failed file(s) listed in .worktreeinclude. The worktree was still created." >&2
    return 1
  fi
  return 0
}

# Runs the setup script inside <worktree>. The script is the file named by `gitwt.postCreate`
# (a path relative to the worktree root) or, when that isn't set, .gitwt/post-create. Setting it
# to an empty value turns setup off. The script comes from the repo, so it only runs once this
# exact version is approved; the approval is stored as its hash in the repo's local git config.
# Returns non-zero if the script failed, or if the configured script can't be used.
_gitwt_run_post_create() {
  local worktree="$1" branch="$2" main_root="$3"
  local rel configured=0

  if rel="$(git -C "$worktree" config --get gitwt.postCreate)"; then
    configured=1
    [[ -n "$rel" ]] || return 0
  else
    rel=".gitwt/post-create"
  fi

  local script="$worktree/$rel"

  if (( configured )); then
    case "/$rel/" in
      //*|*/../*)
        echo "Warning: gitwt.postCreate must be a path inside the repo, not '$rel'. No setup script was run." >&2
        return 1 ;;
    esac
    if [[ ! -f "$script" ]]; then
      echo "Warning: gitwt.postCreate is set to '$rel', but that file doesn't exist in the new worktree. No setup script was run." >&2
      return 1
    fi
    if [[ ! -x "$script" ]]; then
      echo "Warning: gitwt.postCreate is set to '$rel', but that file isn't executable. No setup script was run." >&2
      return 1
    fi
  else
    [[ -f "$script" ]] || return 0
    if [[ ! -x "$script" ]]; then
      echo "Note: $rel is not executable, skipping it." >&2
      return 0
    fi
  fi

  local script_hash answer
  script_hash="$(git -C "$worktree" hash-object --no-filters "$script")"
  if [[ "$(git -C "$worktree" config --get gitwt.postCreateApproved)" != "$script_hash" ]]; then
    if [[ ! -t 0 ]]; then
      echo "Note: $rel is not approved, skipping it. Run 'gitwt new' from a terminal to approve it." >&2
      return 0
    fi
    printf "This repo has a setup script that hasn't been approved: %s\n" "$script"
    printf "Review it first if you're unsure. Run it now and whenever it's unchanged? [y/N] "
    read -r answer
    case "$answer" in
      y|Y|yes) git -C "$worktree" config --local gitwt.postCreateApproved "$script_hash" ;;
      *)       echo "Skipped $rel."; return 0 ;;
    esac
  fi

  echo "Running $rel..."
  if ! ( cd "$worktree" && GITWT_BRANCH="$branch" GITWT_WORKTREE="$worktree" GITWT_MAIN_ROOT="$main_root" "$script" ); then
    echo "Warning: $rel failed. The worktree was still created." >&2
    return 1
  fi
}

# Sets up a worktree that was just added, then cd's into it. Runs from the caller's directory.
_gitwt_finish_new() {
  local worktree="$1" branch="$2" main_root setup_status=0
  main_root="$(_gitwt_main_repo_root)"

  _gitwt_note_if_untracked_in_repo "$worktree"
  _gitwt_copy_included "$main_root" "$worktree" || setup_status=1
  _gitwt_run_post_create "$worktree" "$branch" "$main_root" || setup_status=1

  echo "Done! Switching into it now..."
  cd "$worktree" || return 1
  return $setup_status
}

# ── subcommands ────────────────────────────────────────────────────────────────

_gitwt_new() {
  local branch="" from_branch="" do_fetch=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --fetch)  do_fetch=1 ; shift ;;
      --from=*) set -- --from "${1#--from=}" "${@:2}" ;;
      --from)
        # A bare `shift 2` fails without shifting when the value is missing, which loops forever.
        if [[ $# -lt 2 || -z "$2" || "$2" == -* ]]; then
          echo "Error: --from requires a base branch." >&2
          echo "Usage: gitwt new <branch-name> [--from <base>] [--fetch]" >&2
          return 1
        fi
        from_branch="$2" ; shift 2 ;;
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
    _gitwt_explain_existing_path "$branch" "$worktree_path"
    return 1
  fi

  # Branch already exists locally — just attach a worktree, no branch creation
  if git show-ref --verify --quiet "refs/heads/$branch"; then
    if [[ -n "$from_branch" || "$do_fetch" -eq 1 ]]; then
      echo "Note: --from and --fetch are ignored when the branch already exists." >&2
    fi
    echo "Branch '$branch' exists — creating worktree at: $worktree_path"
    git worktree add "$worktree_path" "$branch" || return 1
    _gitwt_finish_new "$worktree_path" "$branch"
    return $?
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
  git worktree add -b "$branch" "$worktree_path" "$base_branch" || return 1
  _gitwt_finish_new "$worktree_path" "$branch"
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

# Quotes a string for pasting into a shell command.
_gitwt_quote() {
  local q="'"
  printf "'%s'" "${1//$q/$q\\$q$q}"
}

# Whether two paths hold the same file: same contents, or symlinks with the same target.
_gitwt_same_file() {
  local a="$1" b="$2"
  if [[ -L "$a" || -L "$b" ]]; then
    [[ -L "$a" && -L "$b" && "$(readlink "$a")" == "$(readlink "$b")" ]]
    return
  fi
  [[ -f "$a" && -f "$b" ]] && cmp -s "$a" "$b"
}

# Refuses (returns 1) when removing <worktree> would lose a file listed in the main repo's
# .worktreeinclude: one changed in the worktree, or one that exists only there. An unchanged
# copy is fine, because the main repo still has it. Never prompts and never writes anywhere.
_gitwt_check_listed_files() {
  local worktree="$1" main_root="$2" branch="$3"
  local file
  local -a changed only
  changed=(); only=()

  while IFS= read -r -d '' file; do
    if [[ -e "$main_root/$file" || -L "$main_root/$file" ]]; then
      _gitwt_same_file "$main_root/$file" "$worktree/$file" || changed+=("$file")
    else
      only+=("$file")
    fi
  done < <(_gitwt_included_files "$worktree" "$main_root/.worktreeinclude")

  (( ${#changed[@]} + ${#only[@]} > 0 )) || return 0

  echo "Error: removing this worktree would lose files listed in .worktreeinclude." >&2
  if (( ${#changed[@]} > 0 )); then
    echo "Changed here, so they differ from the main repo's copy. To compare:" >&2
    for file in "${changed[@]}"; do
      echo "  diff $(_gitwt_quote "$main_root/$file") $(_gitwt_quote "$worktree/$file")" >&2
    done
  fi
  if (( ${#only[@]} > 0 )); then
    echo "Only in this worktree. To keep a copy in the main repo:" >&2
    local dest dest_dir
    for file in "${only[@]}"; do
      dest="$main_root/$file"
      dest_dir="$(dirname "$dest")"
      if [[ -d "$dest_dir" ]]; then
        echo "  cp -p $(_gitwt_quote "$worktree/$file") $(_gitwt_quote "$dest")" >&2
      else
        echo "  mkdir -p $(_gitwt_quote "$dest_dir") && cp -p $(_gitwt_quote "$worktree/$file") $(_gitwt_quote "$dest")" >&2
      fi
      if ! git -C "$main_root" check-ignore -q -- "$file" 2>/dev/null; then
        echo "    Careful: '$file' isn't ignored in the main repo, so a copy there could be committed." >&2
      fi
    done
  fi
  echo "To remove it anyway and lose them: gitwt remove $branch --force" >&2
  return 1
}

# Mentions, in one line, the ignored files removal will delete that .worktreeinclude doesn't list,
# such as node_modules/. They never block removal.
_gitwt_note_unlisted_ignored() {
  local worktree="$1" main_root="$2"
  local entry listed=$'\n' count=0 shown=""

  while IFS= read -r -d '' entry; do
    listed+="$entry"$'\n'
  done < <(_gitwt_included_files "$worktree" "$main_root/.worktreeinclude")

  # --directory collapses an ignored folder such as node_modules/ into one entry
  while IFS= read -r -d '' entry; do
    [[ "$listed" == *$'\n'"$entry"$'\n'* ]] && continue
    count=$((count + 1))
    (( count <= 3 )) && shown="${shown:+$shown, }$entry"
  done < <(git -C "$worktree" ls-files -z --others --ignored --exclude-standard --directory 2>/dev/null)

  (( count > 0 )) || return 0
  (( count > 3 )) && shown="$shown, and $((count - 3)) more"
  echo "Note: also deleting ignored files: $shown" >&2
  if [[ ! -f "$main_root/.worktreeinclude" ]]; then
    echo "Tip: to have gitwt check files such as .env before removing, list them in .worktreeinclude." >&2
  fi
  return 0
}

_gitwt_remove() {
  local branch="" delete_branch=0 force=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --branch) delete_branch=1 ; shift ;;
      --force)  force=1 ; shift ;;
      *)        branch="$1" ; shift ;;
    esac
  done

  if [[ -z "$branch" ]]; then
    echo "Usage: gitwt remove <type/branch-name> [--branch] [--force]" >&2
    echo "Example: gitwt remove fix/checkin-timeout-issue-103" >&2
    return 1
  fi

  local worktree_path
  worktree_path="$(_gitwt_find_path "$branch")" || return 1

  local main_root wt_physical main_physical
  main_root="$(_gitwt_main_repo_root)"
  wt_physical="$(cd "$worktree_path" && pwd -P)"
  main_physical="$(cd "$main_root" && pwd -P)"

  if [[ "$wt_physical" == "$main_physical" ]]; then
    echo "Error: '$branch' is checked out in the main repo, which isn't a removable worktree." >&2
    return 1
  fi

  if (( ! force )); then
    if [[ -n "$(git -C "$worktree_path" status --porcelain 2>/dev/null)" ]]; then
      echo "Error: '$branch' has uncommitted changes or untracked files. Commit or stash them first." >&2
      echo "To remove it anyway: gitwt remove $branch --force (this permanently discards them)." >&2
      return 1
    fi
    _gitwt_check_listed_files "$worktree_path" "$main_root" "$branch" || return 1
    _gitwt_note_unlisted_ignored "$worktree_path" "$main_root"
  fi

  # Leave the worktree only now that removal goes ahead. Compare physical paths and whole
  # path components, so a symlinked path or a sibling like feature-x-2 isn't mistaken for it.
  local prev_dir="$PWD" inside=0 here
  here="$(pwd -P)"
  [[ "$here" == "$wt_physical" || "$here" == "$wt_physical/"* ]] && inside=1
  if (( inside )); then
    echo "Currently inside worktree — returning to main repo: $main_root"
    cd "$main_root" || return 1
  fi

  echo "Removing worktree: $worktree_path"
  local removed=0
  if (( force )); then
    git worktree remove --force "$worktree_path" && removed=1
  else
    git worktree remove "$worktree_path" && removed=1
  fi
  if (( ! removed )); then
    # git explains why above (for example, a locked worktree); go back to where you were
    (( inside )) && [[ -d "$prev_dir" ]] && cd "$prev_dir"
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

# Prints the mount point a path is on (or would be on, for a path that doesn't exist yet).
_gitwt_mount_of() {
  local p="$1"
  while [[ ! -e "$p" ]]; do p="$(dirname "$p")"; done
  df -P "$p" 2>/dev/null | awk 'NR == 2 { for (i = 6; i <= NF; i++) printf "%s%s", $i, (i < NF ? " " : "\n") }'
}

# Whether the worktree registered at <path> is locked.
_gitwt_is_locked() {
  git worktree list --porcelain | awk -v target="$1" '
    /^worktree / { path = substr($0, 10) }
    /^locked/    { if (path == target) found = 1 }
    END          { exit !found }
  '
}

_gitwt_move() {
  local branch="" dest=""

  while [[ $# -gt 0 ]]; do
    if [[ -z "$branch" ]]; then branch="$1"
    elif [[ -z "$dest" ]]; then dest="$1"
    else
      echo "Error: too many arguments. Usage: gitwt move <branch-name> [<new-path>]" >&2
      return 1
    fi
    shift
  done

  if [[ -z "$branch" ]]; then
    echo "Usage: gitwt move <branch-name> [<new-path>]" >&2
    echo "Without <new-path>, moves it to where gitwt.path puts that branch, e.g. after 'git branch -m'." >&2
    return 1
  fi

  local worktree_path
  worktree_path="$(_gitwt_find_path "$branch")" || return 1

  local main_root wt_physical main_physical
  main_root="$(_gitwt_main_repo_root)"
  wt_physical="$(cd "$worktree_path" && pwd -P)"
  main_physical="$(cd "$main_root" && pwd -P)"

  if [[ "$wt_physical" == "$main_physical" ]]; then
    echo "Error: '$branch' is checked out in the main repo, which can't be moved with gitwt." >&2
    return 1
  fi

  # The destination: the given path (into it, if it's an existing folder or ends in /),
  # or where gitwt.path puts this branch
  local auto=0
  if [[ -z "$dest" ]]; then
    auto=1
    dest="$(_gitwt_generate_path "$branch")" || return 1
  else
    [[ "$dest" == /* ]] || dest="$PWD/$dest"
    # An existing folder, or a path ending in /, means "into this folder"
    if [[ "$dest" == */ || ( -d "$dest" && ! -L "$dest" ) ]]; then
      dest="${dest%/}/$(basename "$worktree_path")"
    fi
    dest="$(_gitwt_normalize_path "$dest")"
  fi

  local dest_physical=""
  [[ -d "$dest" ]] && dest_physical="$(cd "$dest" && pwd -P)"
  if [[ "$dest" == "$worktree_path" || "$dest_physical" == "$wt_physical" ]]; then
    echo "'$branch' is already at: $worktree_path"
    return 0
  fi

  if [[ -e "$dest" || -L "$dest" ]]; then
    if (( auto )); then
      _gitwt_explain_existing_path "$branch" "$dest"
    else
      echo "Error: destination already exists: $dest" >&2
    fi
    return 1
  fi

  if [[ "$dest" == "$worktree_path/"* || "$dest" == "$wt_physical/"* ]]; then
    echo "Error: can't move a worktree into itself: $dest" >&2
    return 1
  fi

  if _gitwt_is_locked "$worktree_path"; then
    echo "Error: '$branch' is locked, so git won't move it." >&2
    echo "Tip: if the lock is no longer needed, run 'git worktree unlock $worktree_path', then move it again." >&2
    return 1
  fi

  if [[ "$(_gitwt_mount_of "$worktree_path")" != "$(_gitwt_mount_of "$dest")" ]]; then
    echo "Error: $dest is on a different drive, and git can only move a worktree within one drive." >&2
    echo "Tip: push or commit your work, remove this worktree, then create it again there with 'gitwt new $branch'." >&2
    return 1
  fi

  # git doesn't create missing parent folders. Remember the first one made, to tidy up on failure.
  local parent first_new=""
  parent="$(dirname "$dest")"
  if [[ ! -d "$parent" ]]; then
    first_new="$parent"
    while [[ ! -d "$(dirname "$first_new")" ]]; do first_new="$(dirname "$first_new")"; done
    mkdir -p "$parent" || return 1
  fi

  local here inside=0 suffix=""
  here="$(pwd -P)"
  if [[ "$here" == "$wt_physical" || "$here" == "$wt_physical/"* ]]; then
    inside=1
    suffix="${here#"$wt_physical"}"
  fi

  echo "Moving '$branch' to: $dest"
  if ! git -C "$main_root" worktree move "$worktree_path" "$dest"; then
    if [[ -n "$first_new" ]]; then
      local d="$parent"
      while rmdir "$d" 2>/dev/null; do
        [[ "$d" == "$first_new" ]] && break
        d="$(dirname "$d")"
      done
    fi
    if [[ -f "$worktree_path/.gitmodules" ]]; then
      echo "Tip: git can't move a worktree that contains submodules. Push or commit your work, remove it, then create it again with 'gitwt new $branch'." >&2
    fi
    return 1
  fi

  if (( inside )); then
    cd "$dest$suffix" 2>/dev/null || cd "$dest" || return 1
    echo "You were inside it, so you're now at: $PWD"
  fi
  _gitwt_note_if_untracked_in_repo "$dest"
  echo "Done. Files are unchanged. Anything that saved the old full path may need recreating or"
  echo "restarting: virtualenvs, build caches, absolute symlinks, or programs still running there."
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
                sync="✓ clean"
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
          [[ -z "$changes" ]] && changes="✓ clean"

          printf "%-40s %-26s %-30s %s\n" "$display_branch" "$sync" "$changes" "$rel"
        fi
        wt_path=""; branch=""; head=""; is_detached=""
        ;;
    esac
  done < <(git worktree list --porcelain)

  if (( stale )); then
    echo ""
    echo "Tip: stale entries detected — run 'git worktree prune' to clean up."
  fi
}

_gitwt_help() {
  cat <<'EOF'
gitwt — a friendly wrapper around git worktree
Full guide: https://github.com/ashikahmad/gitwt/blob/main/docs/usage.md

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
                              Refuses if it would lose uncommitted work, or a file
                              listed in .worktreeinclude that was changed in the
                              worktree or exists only there; it says what to do.
                              Flags:
                                --branch        also delete the local branch
                                --force         remove anyway, discarding all of that

  move <branch-name> [<path>] Move a worktree to another folder; everything in it moves
                              as is. Without <path>, moves it to where gitwt.path puts
                              the branch (e.g. after 'git branch -m'). If you're inside,
                              you move with it. Alias: mv

  list                        Show all worktrees with branch, sync state
                              (ahead/behind upstream), changes, and path.
                              Alias: ls

  version                     Show the current gitwt version.
                              Also: gitwt --version, gitwt -v

  help                        Show this message.

NEW WORKTREE SETUP
  .worktreeinclude            Ignored files in the main repo that match this file
                              (gitignore syntax) are copied into each new worktree.
  .gitwt/post-create          Executable script run inside each new worktree, once
                              you've approved that version of it. Gets GITWT_BRANCH,
                              GITWT_WORKTREE and GITWT_MAIN_ROOT.
  git config gitwt.postCreate <path>
                              Run <path> (relative to the repo root) instead of
                              .gitwt/post-create. Set it to "" to turn setup off.

WORKTREE PATH LAYOUT
  By default, new worktrees are placed at:
    ../worktrees/<repoName>/<type>-<branch-name>

  Examples:
    gitwt new fix/checkin-timeout-issue-103
    → ../worktrees/awesomeRepo/fix-checkin-timeout-issue-103

    gitwt new feature/dark-mode
    → ../worktrees/awesomeRepo/feature-dark-mode

  To change this, set the gitwt.path git config to a template:
    git config --global gitwt.path '~/worktrees/{repo}/{slug}'   # all repos
    git config gitwt.path '.worktrees/{slug}'                    # this repo only

  Placeholders: {repo}, {slug} (feature-dark-mode), {branch} (feature/dark-mode).
  Must include {slug} or {branch}. Relative paths start from the main repo root.
  Use ~ for your home folder; shell variables such as $HOME aren't expanded.
  Existing worktrees stay where they are.

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
