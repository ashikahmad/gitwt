#!/usr/bin/env bats

load 'test_helper'

setup() { setup_repo; }
teardown() { teardown_repo; }

@test "switch: cd into existing worktree" {
  local wt_path="$TEST_WORK_DIR/worktrees/myrepo/feat"
  git worktree add -b feat "$wt_path" HEAD

  run "$GITWT_RUNNER" switch feat
  assert_success
  assert_output --partial "__PWD__:$wt_path"
}

@test "switch: alias sw works" {
  local wt_path="$TEST_WORK_DIR/worktrees/myrepo/feat"
  git worktree add -b feat "$wt_path" HEAD

  run "$GITWT_RUNNER" sw feat
  assert_success
  assert_output --partial "__PWD__:$wt_path"
}

@test "switch: branch has no worktree → error" {
  git branch orphan

  run "$GITWT_RUNNER" switch orphan
  assert_failure
  assert_output --partial "no worktree found"
}

@test "switch: no branch name → usage error" {
  run "$GITWT_RUNNER" switch
  assert_failure
  assert_output --partial "Usage:"
}
