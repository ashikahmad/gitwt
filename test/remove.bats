#!/usr/bin/env bats

load 'test_helper'

setup() { setup_repo; }
teardown() { teardown_repo; }

@test "remove: removes worktree dir" {
  local wt_path="$TEST_WORK_DIR/worktrees/myrepo/feat"
  git worktree add -b feat "$wt_path" HEAD

  run "$GITWT_RUNNER" remove feat
  assert_success
  [[ ! -d "$wt_path" ]]
}

@test "remove: --branch also deletes the local branch" {
  local wt_path="$TEST_WORK_DIR/worktrees/myrepo/feat"
  git worktree add -b feat "$wt_path" HEAD

  run "$GITWT_RUNNER" remove feat --branch
  assert_success
  assert_output --partial "deleted"
  ! git show-ref --verify --quiet "refs/heads/feat"
}

@test "remove: --branch on unmerged branch shows -D tip" {
  local wt_path="$TEST_WORK_DIR/worktrees/myrepo/feat"
  git worktree add -b feat "$wt_path" HEAD
  # add a commit to feat so it's unmerged
  touch "$wt_path/newfile"
  git -C "$wt_path" add newfile
  git -C "$wt_path" commit -m "unmerged"

  run "$GITWT_RUNNER" remove feat --branch
  # worktree removal succeeds but branch -d fails
  assert_output --partial "-D"
}

@test "remove: branch has no worktree → error" {
  git branch orphan

  run "$GITWT_RUNNER" remove orphan
  assert_failure
  assert_output --partial "no worktree found"
}

@test "remove: no branch name → usage error" {
  run "$GITWT_RUNNER" remove
  assert_failure
  assert_output --partial "Usage:"
}

@test "remove: when inside worktree, cd back to main repo" {
  local wt_path="$TEST_WORK_DIR/worktrees/myrepo/feat"
  git worktree add -b feat "$wt_path" HEAD

  # Run the wrapper from inside the worktree
  cd "$wt_path"
  run "$GITWT_RUNNER" remove feat
  assert_success
  assert_output --partial "__PWD__:$TEST_REPO"
}

# ── protecting ignored files (TASK-001) ────────────────────────────────────────

WT_FEAT() { echo "$TEST_WORK_DIR/worktrees/myrepo/feat"; }

# Ignores and lists the given patterns, then creates the worktree with gitwt so listed files are copied.
include_and_new() {
  printf '%s\n' "$@" > .gitignore
  printf '%s\n' "$@" > .worktreeinclude
  git add .gitignore .worktreeinclude
  git commit -qm "include config"
}

@test "protect: an unchanged copy of a listed file doesn't block removal" {
  include_and_new .env
  echo SECRET > .env
  "$GITWT_RUNNER" new feat </dev/null >/dev/null
  assert [ -f "$(WT_FEAT)/.env" ]

  run "$GITWT_RUNNER" remove feat
  assert_success
  refute_output --partial "Error"
  refute_output --partial "Note: also deleting"
  assert [ ! -d "$(WT_FEAT)" ]
}

@test "protect: a listed file changed in the worktree blocks removal" {
  include_and_new .env
  echo SECRET > .env
  "$GITWT_RUNNER" new feat </dev/null >/dev/null
  echo EDITED > "$(WT_FEAT)/.env"

  run "$GITWT_RUNNER" remove feat
  assert_failure 1
  assert_output --partial "would lose files listed in .worktreeinclude"
  assert_output --partial "diff '$TEST_REPO/.env' '$(WT_FEAT)/.env'"
  assert_output --partial "gitwt remove feat --force"
  assert_equal "$(cat "$(WT_FEAT)/.env")" "EDITED"
}

@test "protect: a listed file only in the worktree blocks removal, with a copy command" {
  include_and_new "config/*.json"
  "$GITWT_RUNNER" new feat </dev/null >/dev/null
  mkdir -p "$(WT_FEAT)/config"
  echo '{}' > "$(WT_FEAT)/config/local.json"

  run "$GITWT_RUNNER" remove feat
  assert_failure 1
  assert_output --partial "Only in this worktree"
  assert_output --partial "mkdir -p '$TEST_REPO/config' && cp -p '$(WT_FEAT)/config/local.json' '$TEST_REPO/config/local.json'"
  refute_output --partial "isn't ignored in the main repo"
  assert [ -f "$(WT_FEAT)/config/local.json" ]
}

@test "protect: warns when a worktree-only file isn't ignored in the main repo" {
  echo local.cfg > .worktreeinclude
  git add .worktreeinclude; git commit -qm include
  git switch -qc feat
  echo local.cfg > .gitignore
  git add .gitignore; git commit -qm "ignored on this branch only"
  git switch -q main
  "$GITWT_RUNNER" new feat </dev/null >/dev/null
  echo x > "$(WT_FEAT)/local.cfg"

  run "$GITWT_RUNNER" remove feat
  assert_failure 1
  assert_output --partial "cp -p '$(WT_FEAT)/local.cfg' '$TEST_REPO/local.cfg'"
  assert_output --partial "'local.cfg' isn't ignored in the main repo"
}

@test "protect: file names with spaces and quotes are quoted in the commands" {
  include_and_new "it's a file.txt"
  echo a > "it's a file.txt"
  "$GITWT_RUNNER" new feat </dev/null >/dev/null
  echo b > "$(WT_FEAT)/it's a file.txt"

  run "$GITWT_RUNNER" remove feat
  assert_failure 1
  assert_output --partial "diff '$TEST_REPO/it'\\''s a file.txt' '$(WT_FEAT)/it'\\''s a file.txt'"
}

@test "protect: --force removes despite listed files and uncommitted changes" {
  include_and_new .env
  echo SECRET > .env
  "$GITWT_RUNNER" new feat </dev/null >/dev/null
  echo EDITED > "$(WT_FEAT)/.env"
  echo wip > "$(WT_FEAT)/untracked.txt"

  run "$GITWT_RUNNER" remove feat --force
  assert_success
  assert [ ! -d "$(WT_FEAT)" ]
}

@test "protect: unlisted ignored files are mentioned in one line, without blocking" {
  include_and_new .env "node_modules/" "dist/" "*.log" "tmp/"
  printf '.env\n' > .worktreeinclude
  git add .worktreeinclude; git commit -qm "only .env listed"
  "$GITWT_RUNNER" new feat </dev/null >/dev/null
  mkdir -p "$(WT_FEAT)/node_modules/a" "$(WT_FEAT)/dist" "$(WT_FEAT)/tmp"
  touch "$(WT_FEAT)/node_modules/a/i.js" "$(WT_FEAT)/dist/out.js" "$(WT_FEAT)/debug.log" "$(WT_FEAT)/tmp/x"

  run "$GITWT_RUNNER" remove feat
  assert_success
  assert_output --partial "Note: also deleting ignored files: "
  assert_output --partial "and 1 more"
  refute_output --partial "list them in .worktreeinclude"
  assert [ ! -d "$(WT_FEAT)" ]
}

@test "protect: without .worktreeinclude, suggests adding one" {
  echo .env > .gitignore
  git add .gitignore; git commit -qm ignore
  git worktree add -q -b feat "$(WT_FEAT)" HEAD
  echo x > "$(WT_FEAT)/.env"

  run "$GITWT_RUNNER" remove feat
  assert_success
  assert_output --partial "Note: also deleting ignored files: .env"
  assert_output --partial "list them in .worktreeinclude"
}

@test "remove: the main repo's own branch is refused" {
  run "$GITWT_RUNNER" remove main
  assert_failure 1
  assert_output --partial "checked out in the main repo"
  refute_output --partial "--force"
  assert [ -d "$TEST_REPO/.git" ]
}

@test "remove: a refused removal leaves you inside the worktree" {
  include_and_new .env
  echo SECRET > .env
  "$GITWT_RUNNER" new feat </dev/null >/dev/null
  echo EDITED > "$(WT_FEAT)/.env"

  cd "$(WT_FEAT)"
  run "$GITWT_RUNNER" remove feat
  assert_failure 1
  assert_output --partial "__PWD__:$(WT_FEAT)"
}

@test "remove: uncommitted work is refused up front, without moving you" {
  git worktree add -q -b feat "$(WT_FEAT)" HEAD
  echo wip > "$(WT_FEAT)/untracked.txt"

  cd "$(WT_FEAT)"
  run "$GITWT_RUNNER" remove feat
  assert_failure 1
  assert_output --partial "has uncommitted changes or untracked files"
  assert_output --partial "gitwt remove feat --force (this permanently discards them)"
  refute_output --partial "returning to main repo"
  assert_output --partial "__PWD__:$(WT_FEAT)"
  assert [ -f "$(WT_FEAT)/untracked.txt" ]
}

@test "remove: when git itself refuses, you're returned to where you were" {
  git worktree add -q -b feat "$(WT_FEAT)" HEAD
  git worktree lock "$(WT_FEAT)"

  cd "$(WT_FEAT)"
  run "$GITWT_RUNNER" remove feat
  assert_failure 1
  assert_output --partial "locked"
  assert_output --partial "__PWD__:$(WT_FEAT)"
  assert [ -d "$(WT_FEAT)" ]
}

@test "remove: a sibling worktree whose name starts the same doesn't move you" {
  git worktree add -q -b feature/x "$TEST_WORK_DIR/worktrees/myrepo/feature-x" HEAD
  git worktree add -q -b feature/x-2 "$TEST_WORK_DIR/worktrees/myrepo/feature-x-2" HEAD

  cd "$TEST_WORK_DIR/worktrees/myrepo/feature-x-2"
  run "$GITWT_RUNNER" remove feature/x
  assert_success
  refute_output --partial "returning to main repo"
  assert_output --partial "__PWD__:$TEST_WORK_DIR/worktrees/myrepo/feature-x-2"
}

@test "remove: entering through a symlink still moves you out first" {
  git worktree add -q -b feat "$(WT_FEAT)" HEAD
  ln -s "$(WT_FEAT)" "$TEST_WORK_DIR/link"

  cd "$TEST_WORK_DIR/link"
  run "$GITWT_RUNNER" remove feat
  assert_success
  assert_output --partial "returning to main repo"
  assert_output --partial "__PWD__:$TEST_REPO"
}
