#!/usr/bin/env bats

load 'test_helper'

setup() {
  setup_repo
  WT="$TEST_WORK_DIR/worktrees/myrepo/feat"
}
teardown() { teardown_repo; }

# Ignores the given patterns and lists the given patterns for copying.
ignore_and_include() {
  printf '%s\n' "$@" > .gitignore
  printf '%s\n' "$@" > .worktreeinclude
  git add .gitignore .worktreeinclude
  git commit -qm "setup config"
}

# Commits an executable .gitwt/post-create with the given body.
add_hook() {
  mkdir -p .gitwt
  printf '#!/bin/sh\n%s\n' "$1" > .gitwt/post-create
  chmod +x .gitwt/post-create
  git add .gitwt
  git commit -qm "hook"
}

approve_hook() {
  git config gitwt.postCreateApproved "$(git hash-object --no-filters .gitwt/post-create)"
}

# ── .worktreeinclude ───────────────────────────────────────────────────────────

@test "include: copies listed ignored files, keeping folders and spaces" {
  ignore_and_include .env "config/*.json" "my file.txt"
  echo SECRET > .env
  mkdir config; echo '{}' > config/local.json
  echo x > "my file.txt"
  run "$GITWT_RUNNER" new feat </dev/null
  assert_success
  assert_output --partial "Copied 3 file(s)"
  assert_equal "$(cat "$WT/.env")" "SECRET"
  assert [ -f "$WT/config/local.json" ]
  assert [ -f "$WT/my file.txt" ]
}

@test "include: ignored files that are not listed are not copied" {
  printf '.env\nlocal.db\n' > .gitignore
  echo .env > .worktreeinclude
  git add .gitignore .worktreeinclude; git commit -qm cfg
  echo a > .env; echo b > local.db
  run "$GITWT_RUNNER" new feat </dev/null
  assert_success
  assert [ -f "$WT/.env" ]
  assert [ ! -e "$WT/local.db" ]
}

@test "include: listed files that are not ignored are not copied" {
  echo .env > .gitignore
  printf '.env\nnotes.txt\n' > .worktreeinclude
  git add .gitignore .worktreeinclude; git commit -qm cfg
  echo a > .env; echo b > notes.txt
  run "$GITWT_RUNNER" new feat </dev/null
  assert_success
  assert [ -f "$WT/.env" ]
  assert [ ! -e "$WT/notes.txt" ]
}

@test "include: without the file nothing is copied or mentioned" {
  echo .env > .gitignore
  git add .gitignore; git commit -qm cfg
  echo a > .env
  run "$GITWT_RUNNER" new feat </dev/null
  assert_success
  refute_output --partial "Copied"
  assert [ ! -e "$WT/.env" ]
}

@test "include: copies from the main repo when run inside a worktree" {
  ignore_and_include .env
  echo MAIN > .env
  run "$GITWT_RUNNER" new other </dev/null
  assert_success
  cd "$TEST_WORK_DIR/worktrees/myrepo/other"
  echo CHANGED > .env
  run "$GITWT_RUNNER" new feat </dev/null
  assert_success
  assert_equal "$(cat "$WT/.env")" "MAIN"
}

@test "include: also applies when attaching an existing branch" {
  ignore_and_include .env
  echo a > .env
  git branch feat
  run "$GITWT_RUNNER" new feat </dev/null
  assert_success
  assert [ -f "$WT/.env" ]
}

@test "include: a file the branch already has is not overwritten" {
  ignore_and_include .env
  git switch -qc feat
  echo FROM_BRANCH > .env
  git add -f .env; git commit -qm "track env"
  git switch -q main
  echo FROM_MAIN > .env
  run "$GITWT_RUNNER" new feat </dev/null
  assert_success
  assert_output --partial "already there"
  assert_equal "$(cat "$WT/.env")" "FROM_BRANCH"
}

@test "include: a failed copy warns, keeps the worktree, cd's in and returns 1" {
  ignore_and_include .env "config/*.json"
  git switch -qc feat
  echo "not a folder" > config
  git add config; git commit -qm "config is a file on this branch"
  git switch -q main
  echo a > .env
  mkdir config; echo '{}' > config/local.json
  run "$GITWT_RUNNER" new feat </dev/null
  assert_failure 1
  assert_output --partial "could not copy 'config/local.json'"
  assert_output --partial "could not copy 1 file(s)"
  assert_output --partial "Copied 1 file(s)"
  assert_output --partial "__PWD__:$WT"
}

# ── post-create hook ───────────────────────────────────────────────────────────

@test "hook: unapproved script does not run without a terminal" {
  add_hook 'touch hook-ran'
  run "$GITWT_RUNNER" new feat </dev/null
  assert_success
  assert_output --partial "not approved"
  assert [ -d "$WT" ]
  assert [ ! -e "$WT/hook-ran" ]
}

@test "hook: approved script runs in the worktree, after files are copied" {
  ignore_and_include .env
  echo a > .env
  add_hook 'test -f .env && echo "$GITWT_BRANCH|$GITWT_WORKTREE|$GITWT_MAIN_ROOT|$(pwd -P)" > hook-ran'
  approve_hook
  run "$GITWT_RUNNER" new feat </dev/null
  assert_success
  assert_equal "$(cat "$WT/hook-ran")" "feat|$WT|$TEST_REPO|$WT"
}

@test "hook: a changed script needs approval again" {
  add_hook 'touch hook-ran'
  approve_hook
  add_hook 'touch changed-ran'
  run "$GITWT_RUNNER" new feat </dev/null
  assert_success
  assert_output --partial "not approved"
  assert [ ! -e "$WT/changed-ran" ]
}

@test "hook: failure warns, keeps the worktree, cd's in and returns 1" {
  add_hook 'exit 3'
  approve_hook
  run "$GITWT_RUNNER" new feat </dev/null
  assert_failure 1
  assert_output --partial "post-create failed"
  assert_output --partial "__PWD__:$WT"
}

@test "hook: a script that is not executable is skipped with a note" {
  add_hook 'touch hook-ran'
  approve_hook
  chmod -x .gitwt/post-create
  git add .gitwt; git commit -qm "drop mode bit"
  run "$GITWT_RUNNER" new feat </dev/null
  assert_success
  assert_output --partial "is not executable"
  assert [ ! -e "$WT/hook-ran" ]
}

@test "hook: no script means no mention" {
  run "$GITWT_RUNNER" new feat </dev/null
  assert_success
  refute_output --partial "post-create"
}
