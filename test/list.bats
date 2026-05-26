#!/usr/bin/env bats

load 'test_helper'

setup() { setup_repo; }
teardown() { teardown_repo; }

@test "list: shows main branch" {
  run "$GITWT_RUNNER" list
  assert_success
  assert_output --partial "main"
}

@test "list: alias ls works" {
  run "$GITWT_RUNNER" ls
  assert_success
  assert_output --partial "main"
}

@test "list: shows additional worktrees" {
  local wt_path="$TEST_WORK_DIR/worktrees/myrepo/feat"
  git worktree add -b feat "$wt_path" HEAD

  run "$GITWT_RUNNER" list
  assert_success
  assert_output --partial "feat"
}

@test "list: stale worktree shows (stale) and prune tip" {
  local wt_path="$TEST_WORK_DIR/worktrees/myrepo/feat"
  git worktree add -b feat "$wt_path" HEAD
  rm -rf "$wt_path"

  run "$GITWT_RUNNER" list
  assert_success
  assert_output --partial "(stale)"
  assert_output --partial "prune"
}

@test "list: detached HEAD worktree shows (detached:" {
  local wt_path="$TEST_WORK_DIR/worktrees/myrepo/detached"
  local head_sha
  head_sha="$(git rev-parse HEAD)"
  git worktree add --detach "$wt_path" "$head_sha"

  run "$GITWT_RUNNER" list
  assert_success
  assert_output --partial "(detached:"
}

@test "list: clean worktree shows 'clean' in changes column" {
  run "$GITWT_RUNNER" list
  assert_success
  assert_output --partial "clean"
}
