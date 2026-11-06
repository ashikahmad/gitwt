#!/usr/bin/env bats

load 'test_helper'

setup() {
  setup_repo
  W="$TEST_WORK_DIR/worktrees/myrepo"
}
teardown() { teardown_repo; }

registered_path() {
  git worktree list --porcelain | awk -v b="refs/heads/$1" '/^worktree /{p=substr($0,10)} $0=="branch "b{print p}'
}

@test "move: to a given path keeps every kind of file as it was" {
  echo .env > .gitignore; git add .gitignore; git commit -qm ignore
  git worktree add -q -b feat "$W/feat" HEAD
  echo E > "$W/feat/.env"
  echo u > "$W/feat/untracked.txt"
  echo s > "$W/feat/staged.txt"; git -C "$W/feat" add staged.txt
  echo m >> "$W/feat/.gitignore"
  before="$(git -C "$W/feat" status --porcelain)"

  run "$GITWT_RUNNER" move feat "$TEST_WORK_DIR/elsewhere"
  assert_success
  assert_equal "$(registered_path feat)" "$TEST_WORK_DIR/elsewhere"
  assert [ ! -e "$W/feat" ]
  assert_equal "$(git -C "$TEST_WORK_DIR/elsewhere" status --porcelain)" "$before"
  assert_equal "$(cat "$TEST_WORK_DIR/elsewhere/.env")" "E"
  assert_output --partial "Files are unchanged"
}

@test "move: without a path, follows a renamed branch" {
  git worktree add -q -b feature/old "$W/feature-old" HEAD
  git branch -m feature/old feature/new

  run "$GITWT_RUNNER" move feature/new
  assert_success
  assert_equal "$(registered_path feature/new)" "$W/feature-new"
  assert [ ! -e "$W/feature-old" ]
}

@test "move: without a path, follows a changed gitwt.path" {
  git worktree add -q -b feat "$W/feat" HEAD
  git config gitwt.path '../wt2/{slug}'

  run "$GITWT_RUNNER" move feat
  assert_success
  assert_equal "$(registered_path feat)" "$TEST_WORK_DIR/wt2/feat"
}

@test "move: already in place says so and changes nothing" {
  git worktree add -q -b feat "$W/feat" HEAD

  run "$GITWT_RUNNER" move feat
  assert_success
  assert_output --partial "already at"
  refute_output --partial "Files are unchanged"
}

@test "move: into an existing folder, like mv" {
  git worktree add -q -b feat "$W/feat" HEAD
  mkdir "$TEST_WORK_DIR/box"

  run "$GITWT_RUNNER" move feat "$TEST_WORK_DIR/box"
  assert_success
  assert_equal "$(registered_path feat)" "$TEST_WORK_DIR/box/feat"
}

@test "move: a path ending in / means into that folder, even if it doesn't exist yet" {
  git worktree add -q -b feat "$W/feat" HEAD

  run "$GITWT_RUNNER" move feat "$TEST_WORK_DIR/archive/"
  assert_success
  assert_equal "$(registered_path feat)" "$TEST_WORK_DIR/archive/feat"
}

@test "move: a relative path starts from the current folder" {
  git worktree add -q -b feat "$W/feat" HEAD

  run "$GITWT_RUNNER" move feat ../rel-dest
  assert_success
  assert_equal "$(registered_path feat)" "$TEST_WORK_DIR/rel-dest"
}

@test "move: creates missing parent folders" {
  git worktree add -q -b feat "$W/feat" HEAD

  run "$GITWT_RUNNER" move feat "$TEST_WORK_DIR/a/b/c"
  assert_success
  assert_equal "$(registered_path feat)" "$TEST_WORK_DIR/a/b/c"
}

@test "move: from inside, you end up in the same subfolder at the new place" {
  git worktree add -q -b feat "$W/feat" HEAD
  mkdir -p "$W/feat/src/deep"

  cd "$W/feat/src/deep"
  run "$GITWT_RUNNER" move feat "$TEST_WORK_DIR/moved"
  assert_success
  assert_output --partial "__PWD__:$TEST_WORK_DIR/moved/src/deep"
}

@test "move: from elsewhere, you stay where you are" {
  git worktree add -q -b feat "$W/feat" HEAD

  run "$GITWT_RUNNER" move feat "$TEST_WORK_DIR/moved"
  assert_success
  assert_output --partial "__PWD__:$TEST_REPO"
}

@test "move: the main repo is refused" {
  run "$GITWT_RUNNER" move main "$TEST_WORK_DIR/x"
  assert_failure 1
  assert_output --partial "checked out in the main repo"
  assert [ ! -e "$TEST_WORK_DIR/x" ]
}

@test "move: an existing destination file is refused" {
  git worktree add -q -b feat "$W/feat" HEAD
  touch "$TEST_WORK_DIR/taken"

  run "$GITWT_RUNNER" move feat "$TEST_WORK_DIR/taken"
  assert_failure 1
  assert_output --partial "destination already exists"
  assert_equal "$(registered_path feat)" "$W/feat"
}

@test "move: a taken default path says which branch has it" {
  git worktree add -q -b feature/a-b "$W/feature-a-b" HEAD
  git worktree add -q -b feature-a/b "$W/other" HEAD

  run "$GITWT_RUNNER" move feature-a/b
  assert_failure 1
  assert_output --partial "belongs to branch 'feature/a-b'"
  assert_equal "$(registered_path feature-a/b)" "$W/other"
}

@test "move: into itself is refused" {
  git worktree add -q -b feat "$W/feat" HEAD

  run "$GITWT_RUNNER" move feat "$W/feat/sub"
  assert_failure 1
  assert_output --partial "into itself"
  assert [ ! -e "$W/feat/sub" ]
}

@test "move: a locked worktree is refused, with how to unlock" {
  git worktree add -q -b feat "$W/feat" HEAD
  git worktree lock "$W/feat"

  run "$GITWT_RUNNER" move feat "$TEST_WORK_DIR/moved"
  assert_failure 1
  assert_output --partial "is locked"
  assert_output --partial "git worktree unlock"
  assert_equal "$(registered_path feat)" "$W/feat"
  assert [ ! -e "$TEST_WORK_DIR/moved" ]
}

@test "move: a failed move tidies up the folders it created" {
  git worktree add -q -b feat "$W/feat" HEAD
  # Make git's move fail after gitwt's own checks pass, with a stand-in git that refuses to move.
  mkdir -p "$TEST_WORK_DIR/bin"
  printf '#!/bin/sh\nif [ "$1" = "-C" ] && [ "$3" = worktree ] && [ "$4" = move ]; then echo "fatal: no" >&2; exit 128; fi\nexec %s "$@"\n' "$(command -v git)" > "$TEST_WORK_DIR/bin/git"
  chmod +x "$TEST_WORK_DIR/bin/git"

  PATH="$TEST_WORK_DIR/bin:$PATH" run "$GITWT_RUNNER" move feat "$TEST_WORK_DIR/new/a/b"
  assert_failure 1
  assert [ ! -e "$TEST_WORK_DIR/new" ]
  assert_equal "$(registered_path feat)" "$W/feat"
}

@test "move: inside the repo and not ignored → note with exclude hint" {
  git worktree add -q -b feat "$W/feat" HEAD

  run "$GITWT_RUNNER" move feat .worktrees/feat
  assert_success
  assert_output --partial "not ignored"
}

@test "move: mv alias, and usage errors" {
  git worktree add -q -b feat "$W/feat" HEAD

  run "$GITWT_RUNNER" mv feat "$TEST_WORK_DIR/moved"
  assert_success

  run "$GITWT_RUNNER" move
  assert_failure 1
  assert_output --partial "Usage: gitwt move"

  run "$GITWT_RUNNER" move feat a b
  assert_failure 1
  assert_output --partial "too many arguments"

  run "$GITWT_RUNNER" move nope "$TEST_WORK_DIR/x"
  assert_failure 1
  assert_output --partial "no worktree found"
}

@test "move: another drive is refused before trying" {
  [[ -d /dev/shm && -w /dev/shm ]] || skip "no /dev/shm"
  [[ "$(df -P /dev/shm | awk 'NR==2{print $6}')" != "$(df -P "$TEST_WORK_DIR" | awk 'NR==2{print $6}')" ]] \
    || skip "/dev/shm is on the same drive here"
  git worktree add -q -b feat "$W/feat" HEAD
  local dest="/dev/shm/gitwt-move-test-$$"

  run "$GITWT_RUNNER" move feat "$dest/feat"
  assert_failure 1
  assert_output --partial "different drive"
  assert [ ! -e "$dest" ]
  assert_equal "$(registered_path feat)" "$W/feat"
}

@test "move: a worktree with submodules gets git's refusal and a tip" {
  local sub="$TEST_WORK_DIR/sub"
  git init -q -b main "$sub"
  git -C "$sub" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  git worktree add -q -b feat "$W/feat" HEAD
  git -C "$W/feat" -c protocol.file.allow=always submodule add -q "$sub" lib 2>/dev/null
  git -C "$W/feat" -c user.email=t@t -c user.name=t commit -qm "add submodule"

  run "$GITWT_RUNNER" move feat "$TEST_WORK_DIR/moved"
  assert_failure 1
  assert_output --partial "contains submodules"
  assert_equal "$(registered_path feat)" "$W/feat"
}
