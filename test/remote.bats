#!/usr/bin/env bats

load 'test_helper'

setup() {
  setup_repo
  ORIGIN="$TEST_WORK_DIR/origin.git"
  git init -q --bare "$ORIGIN"
  git remote add origin "$ORIGIN"
  git push -q -u origin main
}
teardown() { teardown_repo; }

# Puts <branch> on <remote> with one commit main doesn't have, fetched but with no local branch
remote_only_branch() {
  local branch="$1" remote="${2:-origin}"
  git switch -q -c "$branch"
  git commit -q --allow-empty -m "on $branch"
  git push -q "$remote" "refs/heads/$branch:refs/heads/$branch"
  git switch -q main
  git branch -q -D "$branch"
}

# Pushes a commit to <branch> on origin from another clone, so this repo hasn't fetched it
push_from_elsewhere() {
  local branch="$1" other="$TEST_WORK_DIR/elsewhere"
  [[ -d "$other" ]] || git clone -q "$ORIGIN" "$other"
  git -C "$other" config user.email "test@test.com"
  git -C "$other" config user.name "Test"
  git -C "$other" fetch -q origin
  if git -C "$other" show-ref --verify --quiet "refs/remotes/origin/$branch"; then
    git -C "$other" switch -q -C "$branch" "origin/$branch"
  else
    git -C "$other" switch -q -c "$branch"
  fi
  git -C "$other" commit -q --allow-empty -m "elsewhere on $branch"
  git -C "$other" push -q origin "$branch"
  git -C "$other" rev-parse HEAD
}

upstream_of() { git rev-parse --abbrev-ref --symbolic-full-name "$1@{upstream}" 2>/dev/null; }

# ── a branch that's only on the remote ─────────────────────────────────────────

@test "remote: branch only on origin gets a local branch tracking it" {
  remote_only_branch feature/x
  run "$GITWT_RUNNER" new feature/x
  assert_success
  assert_output --partial "tracks 'origin/feature/x'"
  assert_output --partial "as of your last fetch"
  assert_output --partial "__PWD__:$TEST_WORK_DIR/worktrees/myrepo/feature-x"
  assert_equal "$(upstream_of feature/x)" "origin/feature/x"
  assert_equal "$(git rev-parse feature/x)" "$(git rev-parse origin/feature/x)"
}

@test "remote: origin/<branch> names the local branch without the remote" {
  remote_only_branch feature/x
  run "$GITWT_RUNNER" new origin/feature/x
  assert_success
  assert_output --partial "__PWD__:$TEST_WORK_DIR/worktrees/myrepo/feature-x"
  assert_equal "$(upstream_of feature/x)" "origin/feature/x"
  run git show-ref --verify --quiet refs/heads/origin/feature/x
  assert_failure
}

@test "remote: --fetch finds a branch that was never fetched" {
  local tip
  tip="$(push_from_elsewhere feature/y)"
  run "$GITWT_RUNNER" new feature/y --fetch
  assert_success
  assert_output --partial "tracks 'origin/feature/y'"
  refute_output --partial "as of your last fetch"
  assert_equal "$(git rev-parse feature/y)" "$tip"
  assert_equal "$(upstream_of feature/y)" "origin/feature/y"
}

@test "remote: origin/<branch> --fetch finds a branch that was never fetched" {
  local tip
  tip="$(push_from_elsewhere feature/y)"
  run "$GITWT_RUNNER" new origin/feature/y --fetch
  assert_success
  assert_equal "$(git rev-parse feature/y)" "$tip"
}

@test "remote: --fetch gets commits pushed after the last fetch" {
  remote_only_branch feature/x
  local tip
  tip="$(push_from_elsewhere feature/x)"
  run "$GITWT_RUNNER" new feature/x --fetch
  assert_success
  assert_equal "$(git rev-parse feature/x)" "$tip"
}

@test "remote: without --fetch, a branch never fetched is created new, as before" {
  push_from_elsewhere feature/y >/dev/null
  run "$GITWT_RUNNER" new feature/y
  assert_success
  assert_output --partial "Creating 'feature/y' from 'main'"
  assert_equal "$(git rev-parse feature/y)" "$(git rev-parse main)"
}

@test "remote: a new branch with --fetch doesn't show git's not-found error" {
  run "$GITWT_RUNNER" new brand-new --fetch
  assert_success
  refute_output --partial "couldn't find remote ref"
  assert_output --partial "Creating 'brand-new' from 'main'"
  assert_equal "$(upstream_of brand-new)" ""
}

@test "remote: --from with a branch that's on the remote → error, nothing created" {
  remote_only_branch feature/x
  run "$GITWT_RUNNER" new feature/x --from main
  assert_failure
  assert_output --partial "already exists on 'origin'"
  run git show-ref --verify --quiet refs/heads/feature/x
  assert_failure
  [[ ! -e "$TEST_WORK_DIR/worktrees/myrepo/feature-x" ]]
}

@test "remote: origin/<branch> with --from → error" {
  remote_only_branch feature/x
  run "$GITWT_RUNNER" new origin/feature/x --from main
  assert_failure
  assert_output --partial "--from doesn't apply"
}

@test "remote: origin/<branch> that isn't known → error suggests --fetch" {
  run "$GITWT_RUNNER" new origin/nope
  assert_failure
  assert_output --partial "isn't a known remote branch"
  assert_output --partial "--fetch"
  run git show-ref --verify --quiet refs/heads/nope
  assert_failure
}

@test "remote: origin/<branch> --fetch that isn't on the remote → error" {
  run "$GITWT_RUNNER" new origin/nope --fetch
  assert_failure
  assert_output --partial "'origin' has no branch 'nope'"
  run git show-ref --verify --quiet refs/heads/nope
  assert_failure
}

@test "remote: origin/<branch> when the local branch exists uses it, with a note" {
  remote_only_branch feature/x
  git branch feature/x main
  run "$GITWT_RUNNER" new origin/feature/x
  assert_success
  assert_output --partial "may differ from 'origin/feature/x'"
  assert_equal "$(git rev-parse feature/x)" "$(git rev-parse main)"
}

@test "remote: a local branch really named origin/<x> is used as is" {
  git branch origin/x
  run "$GITWT_RUNNER" new origin/x
  assert_success
  assert_output --partial "exists — creating worktree"
  assert_output --partial "__PWD__:$TEST_WORK_DIR/worktrees/myrepo/origin-x"
}

@test "remote: on two remotes → error naming both" {
  git init -q --bare "$TEST_WORK_DIR/upstream.git"
  git remote add upstream "$TEST_WORK_DIR/upstream.git"
  remote_only_branch feature/x
  git push -q upstream origin/feature/x:refs/heads/feature/x
  git fetch -q upstream
  run "$GITWT_RUNNER" new feature/x
  assert_failure
  assert_output --partial "more than one remote: origin, upstream"
  assert_output --partial "gitwt new origin/feature/x"
}

@test "remote: on two remotes, checkout.defaultRemote picks one" {
  git init -q --bare "$TEST_WORK_DIR/upstream.git"
  git remote add upstream "$TEST_WORK_DIR/upstream.git"
  remote_only_branch feature/x
  git push -q upstream origin/feature/x:refs/heads/feature/x
  git fetch -q upstream
  git config checkout.defaultRemote upstream
  run "$GITWT_RUNNER" new feature/x
  assert_success
  assert_equal "$(upstream_of feature/x)" "upstream/feature/x"
}

@test "remote: a tracked branch still gets the new worktree setup" {
  echo .env > .gitignore
  echo .env > .worktreeinclude
  git add .gitignore .worktreeinclude
  git commit -qm cfg
  git push -q origin main
  echo SECRET > .env
  remote_only_branch feature/x
  run "$GITWT_RUNNER" new feature/x
  assert_success
  assert_equal "$(upstream_of feature/x)" "origin/feature/x"
  assert_equal "$(cat "$TEST_WORK_DIR/worktrees/myrepo/feature-x/.env")" "SECRET"
}

# ── --from with remote branches, tags and commits ──────────────────────────────

@test "from: a remote branch is a base, and the new branch doesn't track it" {
  remote_only_branch release
  run "$GITWT_RUNNER" new feat --from origin/release
  assert_success
  assert_output --partial "Creating 'feat' from 'origin/release'"
  assert_equal "$(git rev-parse feat)" "$(git rev-parse origin/release)"
  assert_equal "$(upstream_of feat)" ""
}

@test "from: a remote branch with --fetch uses its latest commit" {
  remote_only_branch release
  local tip
  tip="$(push_from_elsewhere release)"
  run "$GITWT_RUNNER" new feat --from origin/release --fetch
  assert_success
  assert_equal "$(git rev-parse feat)" "$tip"
  assert_equal "$(upstream_of feat)" ""
}

@test "from: a remote branch that isn't known → error suggests --fetch" {
  run "$GITWT_RUNNER" new feat --from origin/nope
  assert_failure
  assert_output --partial "does not exist"
  assert_output --partial "--fetch"
}

@test "from: a branch only the remote has is used from the remote" {
  remote_only_branch develop
  run "$GITWT_RUNNER" new feat --from develop
  assert_success
  assert_output --partial "'develop' isn't a local branch — using 'origin/develop'"
  assert_equal "$(git rev-parse feat)" "$(git rev-parse origin/develop)"
  assert_equal "$(upstream_of feat)" ""
}

@test "from: a branch only the remote has, never fetched, works with --fetch" {
  local tip
  tip="$(push_from_elsewhere develop)"
  run "$GITWT_RUNNER" new feat --from develop --fetch
  assert_success
  assert_equal "$(git rev-parse feat)" "$tip"
}

@test "from: a tag is a base" {
  git commit -q --allow-empty -m second
  git tag v1 HEAD~1
  run "$GITWT_RUNNER" new feat --from v1
  assert_success
  assert_equal "$(git rev-parse feat)" "$(git rev-parse v1^{commit})"
}

@test "from: a commit SHA is a base" {
  local sha
  sha="$(git rev-parse HEAD)"
  git commit -q --allow-empty -m second
  run "$GITWT_RUNNER" new feat --from "$sha"
  assert_success
  assert_equal "$(git rev-parse feat)" "$sha"
}

@test "from: --fetch with a tag is ignored with a note" {
  git tag v1
  run "$GITWT_RUNNER" new feat --from v1 --fetch
  assert_success
  assert_output --partial "--fetch only applies to branches"
}

@test "from: something that doesn't exist anywhere → error, nothing created" {
  run "$GITWT_RUNNER" new feat --from nowhere --fetch
  assert_failure
  assert_output --partial "base 'nowhere' does not exist"
  run git show-ref --verify --quiet refs/heads/feat
  assert_failure
}

# ── --fetch with a local base ──────────────────────────────────────────────────

@test "fetch: branching from the remote after --fetch sets no upstream" {
  push_from_elsewhere main >/dev/null
  run "$GITWT_RUNNER" new feat --from main --fetch
  assert_success
  assert_output --partial "behind remote — branching from remote"
  assert_equal "$(git rev-parse feat)" "$(git rev-parse origin/main)"
  assert_equal "$(upstream_of feat)" ""
}

@test "fetch: uses the upstream's own name when it differs from the local branch" {
  git push -q origin main:refs/heads/develop
  git fetch -q origin
  git branch -q --track dev origin/develop
  local tip
  tip="$(push_from_elsewhere develop)"
  run "$GITWT_RUNNER" new feat --from dev --fetch
  assert_success
  assert_output --partial "Fetching 'develop' from 'origin'"
  assert_equal "$(git rev-parse feat)" "$tip"
}

@test "fetch: an origin/<same name> branch doesn't win over the real upstream" {
  git push -q origin main:refs/heads/develop
  git commit -q --allow-empty -m "only on origin/dev"
  git push -q origin HEAD:refs/heads/dev
  git reset -q --hard HEAD~1
  git fetch -q origin
  git branch -q --track dev origin/develop
  run "$GITWT_RUNNER" new feat --from dev --fetch
  assert_success
  assert_equal "$(git rev-parse feat)" "$(git rev-parse origin/develop)"
}

# ── second review: --fetch goes by what's on the remote ────────────────────────

# Adds a second remote "upstream" that this repo and the other clone both know
add_upstream() {
  git init -q --bare "$TEST_WORK_DIR/upstream.git"
  git remote add upstream "$TEST_WORK_DIR/upstream.git"
}

@test "review: --fetch with an unreachable remote stops, nothing created" {
  remote_only_branch feature/x
  git remote set-url origin "$TEST_WORK_DIR/nowhere.git"
  run "$GITWT_RUNNER" new feature/x --fetch
  assert_failure
  assert_output --partial "could not ask 'origin' whether it has 'feature/x'"
  run git show-ref --verify --quiet refs/heads/feature/x
  assert_failure
  [[ ! -e "$TEST_WORK_DIR/worktrees/myrepo/feature-x" ]]
}

@test "review: --from <remote-only branch> --fetch with an unreachable remote stops" {
  remote_only_branch develop
  git remote set-url origin "$TEST_WORK_DIR/nowhere.git"
  run "$GITWT_RUNNER" new feat --from develop --fetch
  assert_failure
  assert_output --partial "could not ask 'origin'"
  run git show-ref --verify --quiet refs/heads/feat
  assert_failure
}

@test "review: --from <branch only on a second remote> --fetch uses its latest commit" {
  add_upstream
  git switch -q -c develop
  git commit -q --allow-empty -m d1
  git push -q upstream develop
  git switch -q main
  git branch -q -D develop
  local other="$TEST_WORK_DIR/up-clone" tip
  git clone -q -b develop "$TEST_WORK_DIR/upstream.git" "$other"
  git -C "$other" -c user.email=t@t -c user.name=t commit -q --allow-empty -m d2
  git -C "$other" push -q origin develop
  tip="$(git -C "$other" rev-parse HEAD)"
  run "$GITWT_RUNNER" new feat --from develop --fetch
  assert_success
  assert_output --partial "using 'upstream/develop'"
  assert_equal "$(git rev-parse feat)" "$tip"
}

@test "review: --from with --fetch stops when the branch was pushed but never fetched" {
  push_from_elsewhere feature/x >/dev/null
  run "$GITWT_RUNNER" new feature/x --from main --fetch
  assert_failure
  assert_output --partial "'feature/x' already exists on 'origin'"
  run git show-ref --verify --quiet refs/heads/feature/x
  assert_failure
}

@test "review: a leftover origin/feature blocking origin/feature/x stops, with a prune tip" {
  git push -q origin main:refs/heads/feature
  git fetch -q origin
  local other="$TEST_WORK_DIR/elsewhere"
  git clone -q "$ORIGIN" "$other"
  git -C "$other" push -q origin :refs/heads/feature
  git -C "$other" -c user.email=t@t -c user.name=t commit -q --allow-empty -m fx
  git -C "$other" push -q origin HEAD:refs/heads/feature/x
  run "$GITWT_RUNNER" new feature/x --fetch
  assert_failure
  assert_output --partial "could not fetch 'feature/x' from 'origin'"
  assert_output --partial "'origin/feature', left from an earlier fetch, is in the way"
  assert_output --partial "git fetch --prune origin"
  run git show-ref --verify --quiet refs/heads/feature/x
  assert_failure
  [[ ! -e "$TEST_WORK_DIR/worktrees/myrepo/feature-x" ]]
}

@test "review: a branch deleted on the remote, with --fetch, is new again, with a note" {
  remote_only_branch old
  git push -q origin :refs/heads/old
  git update-ref refs/remotes/origin/old "$(git rev-parse main)"
  run "$GITWT_RUNNER" new old --fetch
  assert_success
  assert_output --partial "'old' has been deleted from 'origin'"
  assert_output --partial "git fetch --prune origin"
  assert_output --partial "Creating 'old' from 'main'"
  assert_equal "$(upstream_of old)" ""
}

@test "review: origin/<branch> --fetch that the remote doesn't have → error" {
  git update-ref refs/remotes/origin/gone "$(git rev-parse main)"
  run "$GITWT_RUNNER" new origin/gone --fetch
  assert_failure
  assert_output --partial "'origin' has no branch 'gone'"
}

@test "review: --from naming both a tag and a remote-only branch asks which" {
  git tag develop
  remote_only_branch develop
  run "$GITWT_RUNNER" new feat --from develop
  assert_failure
  assert_output --partial "both a branch on 'origin' and a tag or commit"
  assert_output --partial "--from origin/develop"
  assert_output --partial "--from refs/tags/develop"
  run git show-ref --verify --quiet refs/heads/feat
  assert_failure

  run "$GITWT_RUNNER" new feat --from origin/develop
  assert_success
  assert_equal "$(git rev-parse feat)" "$(git rev-parse origin/develop)"
  run "$GITWT_RUNNER" new feat2 --from refs/tags/develop
  assert_success
  assert_equal "$(git rev-parse feat2)" "$(git rev-parse 'refs/tags/develop^{commit}')"
}

@test "review: origin/<branch> --fetch when the local branch exists says --fetch is ignored" {
  remote_only_branch feature/x
  git branch feature/x main
  run "$GITWT_RUNNER" new origin/feature/x --fetch
  assert_success
  assert_output --partial "--fetch is ignored"
}
