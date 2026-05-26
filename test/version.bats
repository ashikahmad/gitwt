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
