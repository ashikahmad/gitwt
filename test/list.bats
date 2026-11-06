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
  assert_output --partial "✓ clean"
}

# ── ls -s / --short ────────────────────────────────────────────────────────────

@test "list -s: branch and path only, no header or status columns" {
  git worktree add -q -b feat "$TEST_WORK_DIR/worktrees/myrepo/feat" HEAD

  run "$GITWT_RUNNER" ls -s
  assert_success
  assert_line --regexp '^\* main +myrepo$'
  assert_line --regexp '^  feat +worktrees/myrepo/feat$'
  refute_output --partial "BRANCH"
  refute_output --partial "clean"
}

@test "list --short: marks the worktree you're in, from a subfolder" {
  git worktree add -q -b feat "$TEST_WORK_DIR/worktrees/myrepo/feat" HEAD
  mkdir -p "$TEST_WORK_DIR/worktrees/myrepo/feat/src/deep"

  cd "$TEST_WORK_DIR/worktrees/myrepo/feat/src/deep"
  run "$GITWT_RUNNER" list --short
  assert_success
  assert_line --regexp '^\* feat '
  assert_line --regexp '^  main '
}

@test "list -s: a worktree inside the repo is marked, not the main repo" {
  git worktree add -q -b feat "$TEST_REPO/.worktrees/feat" HEAD

  cd "$TEST_REPO/.worktrees/feat"
  run "$GITWT_RUNNER" ls -s
  assert_success
  assert_line --regexp '^\* feat +myrepo/.worktrees/feat$'
  assert_line --regexp '^  main '
}

@test "list -s: shows detached and stale worktrees, with the prune tip" {
  git worktree add -q --detach "$TEST_WORK_DIR/worktrees/myrepo/det" HEAD
  git worktree add -q -b gone "$TEST_WORK_DIR/worktrees/myrepo/gone" HEAD
  rm -rf "$TEST_WORK_DIR/worktrees/myrepo/gone"

  run "$GITWT_RUNNER" ls -s
  assert_success
  assert_line --regexp '^  \(detached:[0-9a-f]{7}\) +worktrees/myrepo/det$'
  assert_line --regexp '^  \(stale\) +worktrees/myrepo/gone$'
  assert_output --partial "git worktree prune"
}

@test "list -s: a worktree outside the repo's parent folder shows its full path" {
  local elsewhere; elsewhere="$(mktemp -d)"
  git worktree add -q -b far "$elsewhere/far" HEAD

  run "$GITWT_RUNNER" ls -s
  assert_success
  assert_line --regexp "^  far +$(cd "$elsewhere" && pwd -P)/far$"
  rm -rf "$elsewhere"
}

@test "list -s: runs a single git command, however many worktrees" {
  for i in 1 2 3 4 5; do git worktree add -q -b "w$i" "$TEST_WORK_DIR/worktrees/myrepo/w$i" HEAD; done
  mkdir -p "$TEST_WORK_DIR/bin"
  printf '#!/bin/sh\necho "$*" >> "%s/git-calls"\nexec %s "$@"\n' "$TEST_WORK_DIR" "$(command -v git)" > "$TEST_WORK_DIR/bin/git"
  chmod +x "$TEST_WORK_DIR/bin/git"

  PATH="$TEST_WORK_DIR/bin:$PATH" run "$GITWT_RUNNER" ls -s
  assert_success
  assert_equal "$(wc -l < "$TEST_WORK_DIR/git-calls" | tr -d ' ')" "1"
}

@test "list: an unknown option is an error" {
  run "$GITWT_RUNNER" ls --bogus
  assert_failure 1
  assert_output --partial "unknown option '--bogus'"
}
