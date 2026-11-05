#!/usr/bin/env bats

load 'test_helper'

setup() { setup_repo; }
teardown() { teardown_repo; }

@test "path config: unset uses the default layout" {
  run "$GITWT_RUNNER" new feature/dark-mode
  assert_success
  assert_output --partial "__PWD__:$TEST_WORK_DIR/worktrees/myrepo/feature-dark-mode"
}

@test "path config: writing out the default gives the same path" {
  git config gitwt.path '../worktrees/{repo}/{slug}'
  run "$GITWT_RUNNER" new feature/dark-mode
  assert_success
  assert_output --partial "at: $TEST_WORK_DIR/worktrees/myrepo/feature-dark-mode"
  assert_output --partial "__PWD__:$TEST_WORK_DIR/worktrees/myrepo/feature-dark-mode"
}

@test "path config: global setting applies" {
  git config --global gitwt.path '../global/{repo}/{slug}'
  run "$GITWT_RUNNER" new feat
  assert_success
  assert_output --partial "__PWD__:$TEST_WORK_DIR/global/myrepo/feat"
}

@test "path config: repo setting wins over global" {
  git config --global gitwt.path '../global/{slug}'
  git config gitwt.path '../local/{slug}'
  run "$GITWT_RUNNER" new feat
  assert_success
  assert_output --partial "__PWD__:$TEST_WORK_DIR/local/feat"
}

@test "path config: {branch} keeps the slashes" {
  git config gitwt.path '../wt/{branch}'
  run "$GITWT_RUNNER" new feature/dark-mode
  assert_success
  assert_output --partial "__PWD__:$TEST_WORK_DIR/wt/feature/dark-mode"
}

@test "path config: ~ expands to the home directory" {
  git config gitwt.path '~/wt/{repo}/{slug}'
  run "$GITWT_RUNNER" new feat
  assert_success
  assert_output --partial "__PWD__:$HOME/wt/myrepo/feat"
}

@test "path config: absolute path is used as is" {
  git config gitwt.path "$TEST_WORK_DIR/abs/{slug}"
  run "$GITWT_RUNNER" new feat
  assert_success
  assert_output --partial "__PWD__:$TEST_WORK_DIR/abs/feat"
}

@test "path config: relative path starts from the main repo, even inside a worktree" {
  git config gitwt.path '../wt/{slug}'
  git worktree add -b first "$TEST_WORK_DIR/elsewhere/deep/first" HEAD
  cd "$TEST_WORK_DIR/elsewhere/deep/first"
  run "$GITWT_RUNNER" new second
  assert_success
  assert_output --partial "__PWD__:$TEST_WORK_DIR/wt/second"
}

@test "path config: . segments, repeated and trailing slashes are cleaned up" {
  git config gitwt.path '../wt/.//{slug}/'
  run "$GITWT_RUNNER" new feat
  assert_success
  assert_output --partial "at: $TEST_WORK_DIR/wt/feat"
}

@test "path config: branch name with & stays intact" {
  git config gitwt.path '../wt/{slug}'
  run "$GITWT_RUNNER" new 'fix/a&b'
  assert_success
  assert_output --partial "__PWD__:$TEST_WORK_DIR/wt/fix-a&b"
}

@test "path config: no {slug} or {branch} → error, nothing created" {
  git config gitwt.path '../wt/{repo}'
  run "$GITWT_RUNNER" new feat
  assert_failure
  assert_output --partial "must contain {slug} or {branch}"
  [[ ! -e "$TEST_WORK_DIR/wt" ]]
  run git show-ref --verify --quiet refs/heads/feat
  assert_failure
}

@test "path config: empty value → error" {
  git config gitwt.path ''
  run "$GITWT_RUNNER" new feat
  assert_failure
  assert_output --partial "must contain {slug} or {branch}"
}

@test "path config: unknown placeholder → error, nothing created" {
  git config gitwt.path '../wt/{rpeo}/{slug}'
  run "$GITWT_RUNNER" new feat
  assert_failure
  assert_output --partial "unknown placeholder"
  [[ ! -e "$TEST_WORK_DIR/wt" ]]
}

@test "path config: unreadable value → error" {
  git config gitwt.path '~nosuchuser-gitwt/{slug}'
  run "$GITWT_RUNNER" new feat
  assert_failure
  assert_output --partial "could not read gitwt.path"
}

@test "path config: target already exists → error" {
  git config gitwt.path '../wt/{slug}'
  mkdir -p "$TEST_WORK_DIR/wt/feat"
  run "$GITWT_RUNNER" new feat
  assert_failure
  assert_output --partial "already exists"
}

@test "path config: existing branch attaches at the configured path" {
  git branch existing
  git config gitwt.path '../wt/{slug}'
  run "$GITWT_RUNNER" new existing
  assert_success
  assert_output --partial "__PWD__:$TEST_WORK_DIR/wt/existing"
}

@test "path config: inside the repo and not ignored → note with exclude hint" {
  git config gitwt.path '.worktrees/{slug}'
  run "$GITWT_RUNNER" new feat
  assert_success
  assert_output --partial "__PWD__:$TEST_REPO/.worktrees/feat"
  assert_output --partial "not ignored"
  assert_output --partial "echo '.worktrees/' >> .git/info/exclude"
}

@test "path config: inside the repo and ignored → no note" {
  git config gitwt.path '.worktrees/{slug}'
  echo '.worktrees/' >> .git/info/exclude
  run "$GITWT_RUNNER" new feat
  assert_success
  refute_output --partial "not ignored"
}

@test "path config: outside the repo → no note" {
  git config gitwt.path '../wt/{slug}'
  run "$GITWT_RUNNER" new feat
  assert_success
  refute_output --partial "not ignored"
}

@test "path config: switch finds a worktree at a custom path" {
  git config gitwt.path '../wt/{slug}'
  git worktree add -b feat "$TEST_WORK_DIR/wt/feat" HEAD
  run "$GITWT_RUNNER" switch feat
  assert_success
  assert_output --partial "__PWD__:$TEST_WORK_DIR/wt/feat"
}

@test "path config: remove works at a custom path" {
  git config gitwt.path '.worktrees/{slug}'
  git worktree add -b feat "$TEST_REPO/.worktrees/feat" HEAD
  run "$GITWT_RUNNER" remove feat
  assert_success
  [[ ! -d "$TEST_REPO/.worktrees/feat" ]]
}

@test "path config: list shows a path outside the repo's parent in full" {
  local outside
  outside="$(cd "$(mktemp -d -t gitwt-outside-XXXXX)" && pwd -P)"
  git worktree add -b feat "$outside/feat" HEAD
  run "$GITWT_RUNNER" list
  rm -rf "$outside"
  assert_success
  assert_output --partial "$outside/feat"
}

@test "path config: changing it leaves existing worktrees where they are" {
  git worktree add -b feat "$TEST_WORK_DIR/old/feat" HEAD
  git config gitwt.path '../new/{slug}'
  run "$GITWT_RUNNER" switch feat
  assert_success
  assert_output --partial "__PWD__:$TEST_WORK_DIR/old/feat"
}
