#!/usr/bin/env bats

load 'test_helper'

setup() { setup_repo; }
teardown() { teardown_repo; }

@test "new: creates worktree at conventional path and cd's in" {
  run "$GITWT_RUNNER" new feat
  assert_success
  local expected="$TEST_WORK_DIR/worktrees/myrepo/feat"
  [[ -d "$expected" ]]
  assert_output --partial "__PWD__:$expected"
}

@test "new: multi-slash branch name gets slugified" {
  run "$GITWT_RUNNER" new fix/some-bug
  assert_success
  local expected="$TEST_WORK_DIR/worktrees/myrepo/fix-some-bug"
  [[ -d "$expected" ]]
  assert_output --partial "__PWD__:$expected"
}

@test "new: --from <base> creates branch off the specified base" {
  git checkout -b develop
  git checkout main
  run "$GITWT_RUNNER" new feat --from develop
  assert_success
  local expected="$TEST_WORK_DIR/worktrees/myrepo/feat"
  [[ -d "$expected" ]]
}

@test "new: --from nonexistent branch → error status 1" {
  run "$GITWT_RUNNER" new feat --from doesnotexist
  assert_failure
  assert_output --partial "does not exist"
}

@test "new: existing branch attaches worktree and cd's in" {
  git branch existing
  run "$GITWT_RUNNER" new existing
  assert_success
  local expected="$TEST_WORK_DIR/worktrees/myrepo/existing"
  [[ -d "$expected" ]]
  assert_output --partial "exists"
  assert_output --partial "__PWD__:$expected"
}

@test "new: existing branch + --from prints ignored note" {
  git branch existing
  run "$GITWT_RUNNER" new existing --from main
  assert_success
  assert_output --partial "ignored"
}

@test "new: branch already has a worktree → error mentions gitwt switch" {
  local wt_path="$TEST_WORK_DIR/worktrees/myrepo/feat"
  git worktree add -b feat "$wt_path" HEAD

  run "$GITWT_RUNNER" new feat
  assert_failure
  assert_output --partial "gitwt switch"
}

@test "new: worktree path already exists on disk → error mentions gitwt list" {
  local wt_path="$TEST_WORK_DIR/worktrees/myrepo/feat"
  mkdir -p "$wt_path"

  run "$GITWT_RUNNER" new feat
  assert_failure
  assert_output --partial "gitwt list"
}

@test "new: no branch name → usage error status 1" {
  run "$GITWT_RUNNER" new
  assert_failure
  assert_output --partial "Usage:"
}

@test "new: a/b/c branch → slug is a-b-c" {
  run "$GITWT_RUNNER" new a/b/c
  assert_success
  local expected="$TEST_WORK_DIR/worktrees/myrepo/a-b-c"
  [[ -d "$expected" ]]
  assert_output --partial "__PWD__:$expected"
}
