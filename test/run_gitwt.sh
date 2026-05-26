#!/usr/bin/env bash
# Wrapper so bats `run` can invoke gitwt and capture cd behavior.
# After gitwt runs, prints __PWD__:<cwd> so tests can assert the final directory.

GITWT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../gitwt.sh
source "$GITWT_ROOT/gitwt.sh"

gitwt "$@"
_gitwt_exit=$?
echo "__PWD__:$(pwd -P)"
exit $_gitwt_exit
