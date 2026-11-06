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
#
# Everything is inside main(), called on the last line, so a download cut short runs
# nothing at all.

# Plain sh stops here, before any bash-only syntax is read.
if [ -z "${BASH_VERSION:-}" ]; then
  echo "Error: the gitwt installer needs bash. Run it with bash, e.g.:" >&2
  echo "  curl -fsSL https://raw.githubusercontent.com/ashikahmad/gitwt/main/install.sh | bash" >&2
  exit 1
fi

# Sourced, the settings below would stay on in the calling shell.
if (return 0 2>/dev/null); then
  echo "Error: run install.sh with bash, don't source it: bash install.sh" >&2
  return 1
fi

GITWT_VERSION="0.2.0"

main() {
  set -euo pipefail

  local ref="${GITWT_REF:-v$GITWT_VERSION}"
  RAW_URL="https://raw.githubusercontent.com/ashikahmad/gitwt/$ref"
  INSTALL_DIR="$HOME/.config/gitwt"
  FILES=(gitwt.sh _gitwt)
  TMP_DIR="" LOCK_DIR=""
  trap cleanup EXIT

  setup_output

  bold "==> Installing gitwt"
  echo ""

  find_source "$ref"
  mkdir -p "$INSTALL_DIR" || fail "could not create $INSTALL_DIR."
  take_lock
  install_files
  wire_shells
  finish
}

# ── output ─────────────────────────────────────────────────────────────────────

setup_output() {
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
}

fail() {
  red "Error: $*"
  exit 1
}

cleanup() {
  [[ -n "${TMP_DIR:-}" ]] && rm -rf "$TMP_DIR"
  [[ -n "${LOCK_DIR:-}" ]] && rmdir "$LOCK_DIR" 2>/dev/null
  return 0
}

# Prints <path> quoted for the shell only when it needs it (spaces and the like).
shell_quote() {
  if [[ "$1" =~ ^[A-Za-z0-9_./~+-]+$ ]]; then printf '%s' "$1"; else printf '%q' "$1"; fi
}

# ── where the files come from ──────────────────────────────────────────────────

# Follows symlinks to <path> (readlink -f isn't on older macOS).
resolve_link() {
  local p="$1" t
  while [[ -L "$p" ]]; do
    t="$(readlink "$p")"
    if [[ "$t" == /* ]]; then p="$t"; else p="$(dirname "$p")/$t"; fi
  done
  printf '%s' "$p"
}

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

# Sets SOURCE_DIR: a clone, if gitwt.sh and _gitwt sit next to this script (followed
# through symlinks), else a temporary folder with the files downloaded for <ref>.
# Piped through bash, there's no script file, so they're always downloaded.
find_source() {
  local ref="$1" script f
  SOURCE_DIR=""
  script="${BASH_SOURCE[0]:-}"
  if [[ -n "$script" && -f "$script" ]]; then
    script="$(resolve_link "$script")"
    SOURCE_DIR="$(cd "$(dirname "$script")" && pwd)"
    for f in "${FILES[@]}"; do
      [[ -f "$SOURCE_DIR/$f" ]] || SOURCE_DIR=""
    done
  fi

  if [[ -n "$SOURCE_DIR" ]]; then
    echo "From: $SOURCE_DIR"
  else
    echo "From: $RAW_URL"
    TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/gitwt-install.XXXXXX")" || fail "could not create a temporary folder."
    for f in "${FILES[@]}"; do
      fetch "$RAW_URL/$f" "$TMP_DIR/$f" \
        || fail "could not download $f from $RAW_URL. Check your connection, and that '$ref' is a gitwt branch or tag."
    done
    # A failed download can still leave an error page; check these are really gitwt's files
    grep -q '^gitwt() {' "$TMP_DIR/gitwt.sh" || fail "the downloaded gitwt.sh isn't gitwt. Nothing was installed."
    grep -q '^#compdef gitwt' "$TMP_DIR/_gitwt" || fail "the downloaded _gitwt isn't gitwt's completion file. Nothing was installed."
    SOURCE_DIR="$TMP_DIR"
  fi
  echo ""
}

# ── files ──────────────────────────────────────────────────────────────────────

# One install at a time, so two at once can't both add the shell config lines.
take_lock() {
  local tries=0
  until mkdir "$INSTALL_DIR/.install-lock" 2>/dev/null; do
    (( ++tries < 15 )) || fail "another install seems to be running ($INSTALL_DIR/.install-lock exists). If none is, delete that folder and run this again."
    sleep 1
  done
  LOCK_DIR="$INSTALL_DIR/.install-lock"
}

install_files() {
  local f src dest existed
  local clone=0
  # A git clone at ~/.config/gitwt (or a link to one): updating its files by hand would
  # leave the clone with changes, so leave them to git.
  [[ -e "$INSTALL_DIR/.git" ]] && clone=1

  echo "Files in $INSTALL_DIR:"
  for f in "${FILES[@]}"; do
    src="$SOURCE_DIR/$f" dest="$INSTALL_DIR/$f"
    if [[ -e "$dest" && "$src" -ef "$dest" ]]; then
      # Running from a clone at ~/.config/gitwt, or with the files symlinked to it
      green "  $f: already the same file, left as is"
    elif [[ -f "$dest" ]] && cmp -s "$src" "$dest"; then
      green "  $f: already up to date"
    elif [[ -L "$dest" ]]; then
      yellow "  $f: a link to $(readlink "$dest"), left as is. To update it, update that copy, or delete the link and run this again."
    elif (( clone )); then
      yellow "  $f: part of a git clone, left as is. To update it: git -C $(shell_quote "$INSTALL_DIR") pull"
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
}

# ── shell config ───────────────────────────────────────────────────────────────

# Escapes <text> for use in an extended regular expression.
re_escape() {
  printf '%s' "$1" | sed 's/[][\.*^$?+(){}|/]/\\&/g'
}

# Whether <file> has an active line that sources the installed <name>
# (~/.config/gitwt/<name>), written any common way: ~/, $HOME/, ${HOME}/, the full
# path or $XDG_CONFIG_HOME/; with `source` or `.`; quoted or not; at the start of the
# line or after ;, &&, ||, then, do, else, { or (. Commented-out lines don't count, nor
# does a gitwt.sh somewhere else, nor the words inside an echo.
has_source_line() {
  local file="$1" name_re home_re dir_re pfx_re re
  [[ -f "$file" ]] || return 1
  name_re="$(re_escape "$2")"
  home_re="$(re_escape "$HOME")"
  dir_re='(~|\$HOME|\$\{HOME\}|'"$home_re"')/\.config'
  if [[ -z "${XDG_CONFIG_HOME:-}" || "${XDG_CONFIG_HOME%/}" == "$HOME/.config" ]]; then
    dir_re='('"$dir_re"'|\$XDG_CONFIG_HOME|\$\{XDG_CONFIG_HOME\})'
  fi
  # Text before the command, with no comment in it: a # starts a comment only at the
  # start of a word, so PS1="#> " or ${#x} are fine.
  pfx_re='([^#]*[^#[:space:];]#)*[^#]*'
  re='^[[:space:]]*(('"$pfx_re"'([;&|({!]|[[:space:]](then|do|else))|then|do|else)[[:space:]]*)?'
  re+='(source|\.)[[:space:]]+'"$dir_re/gitwt/$name_re"'([[:space:];&|)]|$)'
  # Quotes are dropped first, so "$HOME/.config/gitwt/gitwt.sh", "$HOME"/... and
  # '/home/me/...' all read the same. (No grep -q: stopping early would make tr fail
  # under pipefail.)
  tr -d "\"'" < "$file" | grep -E "$re" >/dev/null
}

# zsh reads its config from $ZDOTDIR, which is often set only in ~/.zshenv, where the
# bash running this can't see it. Ask zsh.
find_zdotdir() {
  local z=""
  if [[ -n "${ZDOTDIR:-}" ]]; then
    z="$ZDOTDIR"
  elif command -v zsh >/dev/null 2>&1; then
    z="$(zsh -c 'printf %s "${ZDOTDIR:-}"' 2>/dev/null </dev/null || true)"
  fi
  printf '%s' "${z:-$HOME}"
}

# Adds the lines <shell> needs to <rc>, unless <rc> or <profile> already has them.
# Creates <rc> when it's missing.
wire_shell() {
  local shell="$1" rc="$2" profile="$3" name line names=() missing=()
  if [[ "$shell" == zsh ]]; then names=(gitwt.sh _gitwt); else names=(gitwt.sh); fi

  for name in "${names[@]}"; do
    if has_source_line "$rc" "$name"; then
      green "  $rc: already loads $name"
    elif has_source_line "$profile" "$name"; then
      green "  $profile: already loads $name"
    else
      missing+=("$name")
    fi
  done
  (( ${#missing[@]} )) || return 0

  if [[ ! -f "$rc" ]]; then
    mkdir -p "$(dirname "$rc")" || fail "could not create $rc."
    if [[ "$shell" == zsh ]]; then
      # zsh's tab-completion needs compinit, which a new .zshrc doesn't run
      printf '# Turn on zsh tab-completion\nautoload -Uz compinit && compinit\n' > "$rc" \
        || fail "could not create $rc."
    else
      : > "$rc" || fail "could not create $rc."
    fi
    yellow "  Created $rc, since there was none."
  fi

  for name in "${missing[@]}"; do
    line="source \"\$HOME/.config/gitwt/$name\""
    printf '\n# gitwt — git worktree helper\n%s\n' "$line" >> "$rc" || fail "could not write to $rc."
    green "  $rc: added a line to load $name"
  done

  if [[ "$shell" == zsh && " ${missing[*]} " == *" _gitwt "* ]] \
    && ! grep -Eq 'compinit|oh-my-zsh|prezto|zimfw|zinit|antidote|antigen|zplug' "$rc"; then
    yellow "  Note: $rc doesn't seem to run compinit, so zsh tab-completion stays off. To turn it on, add this before the gitwt lines:"
    yellow "    autoload -Uz compinit && compinit"
  fi
}

# Wires up the login shell if it's zsh or bash, creating its config if missing, and
# the other one if its config exists.
wire_shells() {
  local zdotdir zshrc bashrc shell
  zdotdir="$(find_zdotdir)"
  zshrc="$zdotdir/.zshrc" bashrc="$HOME/.bashrc"
  WIRED_ZSHRC="" WIRED_BASHRC=""

  shell="${SHELL:-}"; shell="${shell##*/}"
  if [[ -f "$zshrc" || "$shell" == zsh ]]; then WIRED_ZSHRC="$zshrc"; fi
  if [[ -f "$bashrc" || "$shell" == bash ]]; then WIRED_BASHRC="$bashrc"; fi

  if [[ -z "$WIRED_ZSHRC" && -z "$WIRED_BASHRC" ]]; then
    red "Error: found no ~/.zshrc or ~/.bashrc, and your shell (${SHELL:-unknown}) isn't zsh or bash."
    red "gitwt's files are in $INSTALL_DIR. To use them, add this to your zsh or bash config:"
    red "  source \"\$HOME/.config/gitwt/gitwt.sh\""
    exit 1
  fi

  echo "Shell config:"
  if [[ -n "$WIRED_ZSHRC" ]]; then wire_shell zsh "$zshrc" "$zdotdir/.zprofile"; fi
  if [[ -n "$WIRED_BASHRC" ]]; then wire_shell bash "$bashrc" "$HOME/.bash_profile"; fi
  echo ""
}

# ── done ───────────────────────────────────────────────────────────────────────

finish() {
  local version rc rcs=()
  version="$(sed -n 's/^ *local GITWT_VERSION="\([^"]*\)".*/\1/p' "$INSTALL_DIR/gitwt.sh" | head -1)"
  bold "==> gitwt ${version:-?} is installed"
  echo ""
  for rc in "$WIRED_ZSHRC" "$WIRED_BASHRC"; do
    if [[ -n "$rc" && -f "$rc" ]]; then rcs+=("$rc"); fi
  done
  if (( ${#rcs[@]} )); then
    echo "Open a new terminal, or load it in this one:"
    for rc in "${rcs[@]}"; do echo "  source $(shell_quote "$rc")"; done
  else
    echo "Open a new terminal to start using it."
  fi
  echo ""
  echo "Then try:  gitwt help"
}

main "$@"
