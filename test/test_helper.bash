GITWT_RUNNER="$BATS_TEST_DIRNAME/run_gitwt.sh"

load 'libs/bats-support/load'
load 'libs/bats-assert/load'

setup_repo() {
  local _tmpdir
  _tmpdir="$(mktemp -d -t gitwt-test-XXXXX)"
  TEST_WORK_DIR="$(cd "$_tmpdir" && pwd -P)"
  TEST_REPO="$TEST_WORK_DIR/myrepo"
  mkdir "$TEST_REPO"
  git -C "$TEST_REPO" init -b main
  git -C "$TEST_REPO" config user.email "test@test.com"
  git -C "$TEST_REPO" config user.name "Test"
  touch "$TEST_REPO/README.md"
  git -C "$TEST_REPO" add README.md
  git -C "$TEST_REPO" commit -m "init"
  cd "$TEST_REPO" || return 1
}

teardown_repo() {
  cd /tmp || true
  rm -rf "$TEST_WORK_DIR"
}
