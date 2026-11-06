#!/usr/bin/env bats

load 'test_helper'

@test "gitwt version prints version string" {
  run "$GITWT_RUNNER" version
  assert_success
  assert_output --partial "gitwt "
  [[ "$output" =~ gitwt\ [0-9]+\.[0-9]+\.[0-9]+ ]]
}

@test "gitwt --version prints version string" {
  run "$GITWT_RUNNER" --version
  assert_success
  [[ "$output" =~ gitwt\ [0-9]+\.[0-9]+\.[0-9]+ ]]
}

@test "gitwt -v prints version string" {
  run "$GITWT_RUNNER" -v
  assert_success
  [[ "$output" =~ gitwt\ [0-9]+\.[0-9]+\.[0-9]+ ]]
}

# bash 3.2 can't be run here, so the check is tested on a copy of gitwt.sh that reads
# its bash major version as 3.
_as_bash3() {
  sed 's/BASH_VERSINFO\[0\]/3/' "$BATS_TEST_DIRNAME/../gitwt.sh" > "$BATS_TEST_TMPDIR/gitwt3.sh"
  run bash -c "source '$BATS_TEST_TMPDIR/gitwt3.sh'; gitwt $1"
}

@test "bash older than 4: every command stops with the not-supported message" {
  local cmd
  for cmd in ls "new x" "sw main" "remove x" "move x" version help ""; do
    _as_bash3 "$cmd"
    assert_failure 1
    assert_output --partial "gitwt doesn't support bash"
    assert_output --partial "it needs zsh, or bash 4 or newer"
    assert_output --partial "https://ashikahmad.github.io/gitwt/docs/#whats-supported"
  done
}

@test "bash older than 4: nothing else runs, so no cryptic errors" {
  _as_bash3 ls
  refute_output --partial "invalid option"
  refute_output --partial "BRANCH"
  # Just the fact and the link: no advice to change shells
  assert_equal "${#lines[@]}" "2"
}

@test "bash 4+ and zsh: no not-supported message" {
  run bash -c "source '$BATS_TEST_DIRNAME/../gitwt.sh'; gitwt version"
  assert_success
  refute_output --partial "doesn't support"
  if command -v zsh >/dev/null; then
    run zsh -f -c "source '$BATS_TEST_DIRNAME/../gitwt.sh'; gitwt version"
    assert_success
    refute_output --partial "doesn't support"
  fi
}
