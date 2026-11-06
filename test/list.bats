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

# ── full table ─────────────────────────────────────────────────────────────────

# Prints the character position where PATH starts on each table row (header and data),
# counted in characters by bash, since some awks count bytes.
path_columns() {
  local line before n=0
  while IFS= read -r line; do
    n=$((n + 1))
    [[ $n -eq 2 || -z "$line" || "$line" == __PWD__* || "$line" == Tip:* ]] && continue
    before="${line%%@(PATH|myrepo|worktrees/)*}"
    echo "${#before}"
  done <<< "$output" | sort -u
}

@test "list: columns line up, with ✓ and with a long CHANGES value" {
  git worktree add -q -b feat "$TEST_WORK_DIR/worktrees/myrepo/feat" HEAD
  ( cd "$TEST_WORK_DIR/worktrees/myrepo/feat"
    for f in a b c; do echo x > "$f"; done; git add a; echo y > d; echo z >> README.md )

  export LC_ALL=C.UTF-8
  shopt -s extglob
  run "$GITWT_RUNNER" ls
  assert_success
  assert_output --partial "1 staged · 1 modified · 3 untracked"
  assert_output --partial "✓ clean"
  assert_equal "$(path_columns | wc -l | tr -d ' ')" "1"
}

@test "list: marks the worktree you're in" {
  git worktree add -q -b feat "$TEST_WORK_DIR/worktrees/myrepo/feat" HEAD

  cd "$TEST_WORK_DIR/worktrees/myrepo/feat"
  run "$GITWT_RUNNER" ls
  assert_success
  assert_line --regexp '^\* feat '
  assert_line --regexp '^  main '
}

@test "list: ahead and behind counts against the upstream" {
  git init -q --bare "$TEST_WORK_DIR/origin.git"
  git remote add origin "$TEST_WORK_DIR/origin.git"
  git push -q -u origin main
  git worktree add -q -b feat "$TEST_WORK_DIR/worktrees/myrepo/feat" HEAD
  git -C "$TEST_WORK_DIR/worktrees/myrepo/feat" push -q -u origin feat
  git -C "$TEST_WORK_DIR/worktrees/myrepo/feat" commit -q --allow-empty -m one
  git -C "$TEST_WORK_DIR/worktrees/myrepo/feat" commit -q --allow-empty -m two
  git commit -q --allow-empty -m upstream && git push -q origin main && git reset -q --hard HEAD~1

  run "$GITWT_RUNNER" ls
  assert_success
  assert_line --regexp '^\* main +1 behind +✓ clean +myrepo$'
  assert_line --regexp '^  feat +2 ahead +✓ clean +worktrees/myrepo/feat$'
}

@test "list: more worktrees than run at once all come out, in order" {
  for i in $(seq 1 11); do
    git worktree add -q -b "w$(printf %02d "$i")" "$TEST_WORK_DIR/worktrees/myrepo/w$(printf %02d "$i")" HEAD
  done
  echo x > "$TEST_WORK_DIR/worktrees/myrepo/w09/new.txt"

  run "$GITWT_RUNNER" ls
  assert_success
  assert_equal "$(printf '%s\n' "$output" | grep -c 'worktrees/myrepo/w')" "11"
  assert_line --regexp '^  w09 +- +1 untracked +worktrees/myrepo/w09$'
  assert_equal "$(printf '%s\n' "$output" | grep -o 'myrepo/w[0-9]*$' | tr '\n' ' ')" \
    "myrepo/w01 myrepo/w02 myrepo/w03 myrepo/w04 myrepo/w05 myrepo/w06 myrepo/w07 myrepo/w08 myrepo/w09 myrepo/w10 myrepo/w11 "
}

@test "list: one worktree list and one status per worktree" {
  for i in 1 2 3; do git worktree add -q -b "w$i" "$TEST_WORK_DIR/worktrees/myrepo/w$i" HEAD; done
  mkdir -p "$TEST_WORK_DIR/bin"
  printf '#!/bin/sh\necho "$*" >> "%s/git-calls"\nexec %s "$@"\n' "$TEST_WORK_DIR" "$(command -v git)" > "$TEST_WORK_DIR/bin/git"
  chmod +x "$TEST_WORK_DIR/bin/git"

  PATH="$TEST_WORK_DIR/bin:$PATH" run "$GITWT_RUNNER" ls
  assert_success
  assert_equal "$(grep -c 'worktree list' "$TEST_WORK_DIR/git-calls")" "1"
  assert_equal "$(grep -c 'status --porcelain=v2' "$TEST_WORK_DIR/git-calls")" "4"
  assert_equal "$(wc -l < "$TEST_WORK_DIR/git-calls" | tr -d ' ')" "5"
}

@test "list: leaves no temporary files behind" {
  git worktree add -q -b feat "$TEST_WORK_DIR/worktrees/myrepo/feat" HEAD
  mkdir "$TEST_WORK_DIR/tmp"

  TMPDIR="$TEST_WORK_DIR/tmp" run "$GITWT_RUNNER" ls
  assert_success
  assert_equal "$(ls -A "$TEST_WORK_DIR/tmp" | wc -l | tr -d ' ')" "0"
}

@test "list: a bare repo shows as (bare), with no status" {
  git init -q --bare "$TEST_WORK_DIR/proj.git"
  git -C "$TEST_WORK_DIR/proj.git" worktree add -q -b trunk "$TEST_WORK_DIR/trunk"
  git -C "$TEST_WORK_DIR/trunk" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init

  cd "$TEST_WORK_DIR/trunk"
  run "$GITWT_RUNNER" ls
  assert_success
  assert_line --regexp '^  \(bare\) +- +- +proj\.git$'
  assert_line --regexp '^\* trunk '
  refute_output --partial "(detached:)"

  run "$GITWT_RUNNER" ls -s
  assert_line --regexp '^  \(bare\) +proj\.git$'
}
