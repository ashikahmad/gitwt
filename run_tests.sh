#!/usr/bin/env bash
set -euo pipefail
exec "$(dirname "$0")/test/libs/bats-core/bin/bats" test/
