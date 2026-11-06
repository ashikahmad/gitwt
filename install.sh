#!/usr/bin/env bash
# install.sh — gitwt installer
#
# Without a clone:
#   curl -fsSL https://raw.githubusercontent.com/ashikahmad/gitwt/main/install.sh | bash
# From a clone:
#   bash install.sh
#
# Puts gitwt.sh and _gitwt in ~/.config/gitwt/ and adds the lines that load them to
# ~/.zshrc and/or ~/.bashrc. Running it again updates gitwt and adds nothing twice.
# Without a clone it downloads the files for this version's tag; set GITWT_REF to a
# branch or tag to install something else, e.g. GITWT_REF=main.

set -euo pipefail

GITWT_VERSION="0.2.0"
GITWT_REF="${GITWT_REF:-v$GITWT_VERSION}"
GITWT_RAW="https://raw.githubusercontent.com/ashikahmad/gitwt/$GITWT_REF"
INSTALL_DIR="$HOME/.config/gitwt"
FILES=(gitwt.sh _gitwt)

# ── output ─────────────────────────────────────────────────────────────────────

if [[ -t 1 ]]; then
  green()  { printf '\033[32m%s\033[0m\n' "$*"; }
  yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
  red()    { printf '\033[31m%s\033[0m\n' "$*" >&2; }
  bold()   { printf '\033[1m%s\033[0m\n'  "$*"; }
else
  green()  { printf '%s\n' "$*"; }
  yellow() { printf '%s\n' "$*"; }
  red()    { printf '%s\n' "$*" >&2; }
  bold()   { printf '%s\n' "$*"; }
fi

fail() {
  red "Error: $*"
  exit 1
}

# ── where the files come from ──────────────────────────────────────────────────

# A clone: the files sit next to this script. Piped through bash, there is no script
# file, so they're downloaded instead.
SOURCE_DIR=""
if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
  SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for f in "${FILES[@]}"; do
    [[ -f "$SOURCE_DIR/$f" ]] || SOURCE_DIR=""
  done
fi

TMP_DIR=""
cleanup() { [[ -n "$TMP_DIR" ]] && rm -rf "$TMP_DIR"; return 0; }
trap cleanup EXIT

# Downloads <url> to <file> with curl, or wget if there's no curl.
fetch() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1" -o "$2"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$2" "$1"
  else
    fail "downloading gitwt needs curl or wget. Install one of them, or clone the repo and run: bash install.sh"
  fi
}

bold "==> Installing gitwt"
echo ""

if [[ -n "$SOURCE_DIR" ]]; then
  echo "From: $SOURCE_DIR"
else
  echo "From: $GITWT_RAW"
  TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/gitwt-install.XXXXXX")" || fail "could not create a temporary folder."
  for f in "${FILES[@]}"; do
    fetch "$GITWT_RAW/$f" "$TMP_DIR/$f" \
      || fail "could not download $f from $GITWT_RAW. Check your connection, and that '$GITWT_REF' is a gitwt branch or tag."
  done
  # A failed download can still leave an error page; check these are really gitwt's files
  grep -q '^gitwt() {' "$TMP_DIR/gitwt.sh" || fail "the downloaded gitwt.sh isn't gitwt. Nothing was installed."
  grep -q '^#compdef gitwt' "$TMP_DIR/_gitwt" || fail "the downloaded _gitwt isn't gitwt's completion file. Nothing was installed."
  SOURCE_DIR="$TMP_DIR"
fi
echo ""

# ── files ──────────────────────────────────────────────────────────────────────

mkdir -p "$INSTALL_DIR" || fail "could not create $INSTALL_DIR."

echo "Files in $INSTALL_DIR:"
for f in "${FILES[@]}"; do
  src="$SOURCE_DIR/$f" dest="$INSTALL_DIR/$f"
  if [[ -e "$dest" && "$src" -ef "$dest" ]]; then
    # Running from a clone at ~/.config/gitwt, or with the files symlinked to one
    green "  $f: already the same file, left as is"
  elif [[ -f "$dest" ]] && cmp -s "$src" "$dest"; then
    green "  $f: already up to date"
  else
    existed=0
    [[ -e "$dest" ]] && existed=1
    # Copy next to it, then rename over it: works even when the old file is read-only
    cp "$src" "$dest.new.$$" || fail "could not write to $INSTALL_DIR."
    mv -f "$dest.new.$$" "$dest" || { rm -f "$dest.new.$$"; fail "could not replace $dest."; }
    if (( existed )); then green "  $f: updated"; else green "  $f: installed"; fi
  fi
done
echo ""

# ── shell config ───────────────────────────────────────────────────────────────

SOURCE_LINE='source "$HOME/.config/gitwt/gitwt.sh"'
COMPLETION_LINE='source "$HOME/.config/gitwt/_gitwt"'
ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"
BASHRC="$HOME/.bashrc"

# Whether <file> has an active (not commented-out) line that sources <name>, written
# any way: "$HOME/...", ~/..., an absolute path, `source` or `.`.
has_source_line() {
  grep -Eq "^[^#]*(^|[;&|[:space:]])(source|\\.)[[:space:]]+[^#]*/$2(\"|'|[[:space:]]|;|\$)" "$1" 2>/dev/null
}

# Adds <line> to <file> unless an active line already sources <name>.
add_line() {
  local file="$1" name="$2" line="$3"
  if has_source_line "$file" "$name"; then
    green "  $file: already loads $name"
  else
    printf '\n# gitwt — git worktree helper\n%s\n' "$line" >> "$file" || fail "could not write to $file."
    green "  $file: added a line to load $name"
  fi
}

# Wire up the shells whose config exists. With none, create one for the login shell.
targets=()
[[ -f "$ZSHRC" ]] && targets+=(zsh)
[[ -f "$BASHRC" ]] && targets+=(bash)
if (( ${#targets[@]} == 0 )); then
  case "${SHELL##*/}" in
    zsh)  targets=(zsh);  : > "$ZSHRC"  || fail "could not create $ZSHRC." ;;
    bash) targets=(bash); : > "$BASHRC" || fail "could not create $BASHRC." ;;
    *)
      red "Error: found no ~/.zshrc or ~/.bashrc, and your shell (${SHELL:-unknown}) isn't zsh or bash."
      red "gitwt's files are in $INSTALL_DIR. To use them, add this to your zsh or bash config:"
      red "  $SOURCE_LINE"
      exit 1 ;;
  esac
  yellow "Created $( [[ "${targets[0]}" == zsh ]] && echo "$ZSHRC" || echo "$BASHRC" ), since there was none."
fi

echo "Shell config:"
for shell in "${targets[@]}"; do
  if [[ "$shell" == zsh ]]; then
    add_line "$ZSHRC" gitwt.sh "$SOURCE_LINE"
    add_line "$ZSHRC" _gitwt "$COMPLETION_LINE"
  else
    add_line "$BASHRC" gitwt.sh "$SOURCE_LINE"
  fi
done
echo ""

# ── done ───────────────────────────────────────────────────────────────────────

version="$(sed -n 's/^ *local GITWT_VERSION="\([^"]*\)".*/\1/p' "$INSTALL_DIR/gitwt.sh" | head -1)"
bold "==> gitwt ${version:-?} is installed"
echo ""
echo "Open a new terminal, or load it in this one:"
for shell in "${targets[@]}"; do
  if [[ "$shell" == zsh ]]; then echo "  source $ZSHRC"; else echo "  source $BASHRC"; fi
done
echo ""
echo "Then try:  gitwt help"
