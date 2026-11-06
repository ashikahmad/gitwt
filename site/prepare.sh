#!/usr/bin/env bash
# Copies the usage guide into this site, one page per section (see split_guide.rb).
# The landing page (index.html) is written by hand.
# Usage: site/prepare.sh <repo-root> <site-dir>
set -euo pipefail
repo="$1" out="$2"

ruby "$(dirname "$0")/split_guide.rb" "$repo/docs/usage.md" "$out"

cp "$repo/icon.svg" "$out/icon.svg"
