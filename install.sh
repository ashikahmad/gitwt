#!/usr/bin/env bash
# install.sh — gitwt installer
# Copies gitwt.sh and _gitwt to ~/.config/gitwt/ and adds
# the necessary source lines to ~/.zshrc and/or ~/.bashrc.

set -e

INSTALL_DIR="$HOME/.config/gitwt"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── helpers ────────────────────────────────────────────────────────────────────

green()  { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
red()    { printf '\033[31m%s\033[0m\n' "$*"; }
bold()   { printf '\033[1m%s\033[0m\n'  "$*"; }

append_if_missing() {
  local file="$1"
  local line="$2"
  local label="$3"

  if [[ ! -f "$file" ]]; then
    yellow "  $file not found — skipping."
    return
  fi

  if grep -qF "$line" "$file"; then
    yellow "  Already present in $file — skipping."
  else
    printf '\n# gitwt — git worktree helper\n%s\n' "$line" >> "$file"
    green "  Added to $file"
    if [[ -n "$label" ]]; then
      echo "  $label"
    fi
  fi
}

# ── main ───────────────────────────────────────────────────────────────────────

bold "==> Installing gitwt"
echo ""

# 1. Create install directory
echo "Creating $INSTALL_DIR ..."
mkdir -p "$INSTALL_DIR"

# 2. Copy files
echo "Copying files..."
cp "$SCRIPT_DIR/gitwt.sh" "$INSTALL_DIR/gitwt.sh"
cp "$SCRIPT_DIR/_gitwt"   "$INSTALL_DIR/_gitwt"
green "  gitwt.sh and _gitwt copied to $INSTALL_DIR"
echo ""

# 3. Wire up shell configs
echo "Wiring up shell configs..."

SOURCE_LINE="source \"$INSTALL_DIR/gitwt.sh\""
COMPLETION_LINE="source \"$INSTALL_DIR/_gitwt\""

# bashrc — main script only (bash doesn't use the zsh completion file)
append_if_missing "$HOME/.bashrc" "$SOURCE_LINE"

# zshrc — main script + zsh completion
append_if_missing "$HOME/.zshrc" "$SOURCE_LINE"
append_if_missing "$HOME/.zshrc" "$COMPLETION_LINE" "(zsh tab-completion enabled)"

# zprofile / bash_profile fallbacks (macOS uses .zprofile for login shells)
if [[ "$(uname)" == "Darwin" ]]; then
  # Only add if .zshrc doesn't exist (edge case)
  if [[ ! -f "$HOME/.zshrc" ]]; then
    append_if_missing "$HOME/.zprofile" "$SOURCE_LINE"
    append_if_missing "$HOME/.zprofile" "$COMPLETION_LINE"
  fi
fi

echo ""
bold "==> Done!"
echo ""
echo "Reload your shell to start using gitwt:"
echo ""
echo "  For zsh:   source ~/.zshrc"
echo "  For bash:  source ~/.bashrc"
echo ""
echo "Then try:  gitwt help"
echo ""
