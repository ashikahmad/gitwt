#!/usr/bin/env bash
# Copies the usage guide into this site as the docs home page, fixing its links.
# The landing page (index.html) is written by hand.
# Usage: site/prepare.sh <repo-root> <site-dir>
set -euo pipefail
repo="$1" out="$2"

mkdir -p "$out/docs"
{
  printf -- '---\ntitle: Usage guide\nnav_order: 1\npermalink: /docs/\n---\n\n'
  sed -e 's|the \[README\](\.\./README\.md)|the [home page](../)|g' \
      -e 's|](\.\./README\.md)|](../)|g' "$repo/docs/usage.md"
} > "$out/docs/index.md"

cp "$repo/icon.svg" "$out/icon.svg"
