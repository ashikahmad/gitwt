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

@test "path config: shell variables like \$HOME → error, nothing created" {
  git config gitwt.path '$HOME/wts/{slug}'
  run "$GITWT_RUNNER" new feat
  assert_failure
  assert_output --partial "can't use shell variables"
  assert_output --partial "Use ~"
  [[ ! -e "$TEST_REPO/\$HOME" ]]
  run git show-ref --verify --quiet refs/heads/feat
  assert_failure
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

@test "path clash: names the branch that owns the folder, nothing created" {
  run "$GITWT_RUNNER" new feature/a-b
  assert_success
  run "$GITWT_RUNNER" new feature-a/b
  assert_failure
  assert_output --partial "worktree path already exists"
  assert_output --partial "belongs to branch 'feature/a-b'"
  assert_output --partial "'feature-a/b' maps to the same folder"
  run git show-ref --verify --quiet refs/heads/feature-a/b
  assert_failure
}

@test "path clash: {branch} keeps those two branches apart" {
  git config gitwt.path '../wt/{branch}'
  run "$GITWT_RUNNER" new feature/a-b
  assert_success
  run "$GITWT_RUNNER" new feature-a/b
  assert_success
}

@test "path clash: detached worktree in the folder is explained" {
  git worktree add --detach "$TEST_WORK_DIR/worktrees/myrepo/feat" HEAD
  run "$GITWT_RUNNER" new feat
  assert_failure
  assert_output --partial "detached HEAD"
}

@test "path clash: another repo in the folder is named" {
  git config --global gitwt.path '../wt/{slug}'
  run "$GITWT_RUNNER" new feat
  assert_success

  local other="$TEST_WORK_DIR/other"
  git init -b main "$other"
  git -C "$other" config user.email "test@test.com"
  git -C "$other" config user.name "Test"
  git -C "$other" commit --allow-empty -m "init"
  cd "$other"
  run "$GITWT_RUNNER" new feat
  assert_failure
  assert_output --partial "checkout of another repo: $TEST_REPO"
}

@test "path clash: owner is found when the configured path goes through a symlink" {
  mkdir "$TEST_WORK_DIR/real"
  ln -s "$TEST_WORK_DIR/real" "$TEST_WORK_DIR/link"
  git config gitwt.path "$TEST_WORK_DIR/link/{slug}"
  run "$GITWT_RUNNER" new feature/a-b
  assert_success
  run "$GITWT_RUNNER" new feature-a/b
  assert_failure
  assert_output --partial "belongs to branch 'feature/a-b'"
}

@test "path clash: folder that isn't a worktree says so" {
  git config gitwt.path '../wt/{slug}'
  mkdir -p "$TEST_WORK_DIR/wt/feat"
  run "$GITWT_RUNNER" new feat
  assert_failure
  assert_output --partial "isn't a worktree of this repo"
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

@test "path config: the not-ignored note comes before setup output" {
  git config gitwt.path '.worktrees/{slug}'
  mkdir -p .gitwt
  printf '#!/bin/sh\necho SETUP-RAN\n' > .gitwt/post-create
  chmod +x .gitwt/post-create
  git add .gitwt; git commit -qm hook
  git config gitwt.postCreateApproved "$(git hash-object --no-filters .gitwt/post-create)"
  run "$GITWT_RUNNER" new feat </dev/null
  assert_success
  note_line="$(printf '%s\n' "$output" | grep -n 'not ignored' | cut -d: -f1)"
  setup_line="$(printf '%s\n' "$output" | grep -n 'SETUP-RAN' | cut -d: -f1)"
  [[ -n "$note_line" && -n "$setup_line" && "$note_line" -lt "$setup_line" ]]
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
