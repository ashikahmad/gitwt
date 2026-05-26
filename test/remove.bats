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
