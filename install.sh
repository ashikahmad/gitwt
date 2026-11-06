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
  return 1 2>/dev/null || exit 1
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
  TMP_DIR="" LOCK_DIR="" PARTIAL=""
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
  [[ -n "${PARTIAL:-}" ]] && rm -f "$PARTIAL"
  [[ -n "${LOCK_DIR:-}" ]] && rm -f "$LOCK_DIR/pid" && rmdir "$LOCK_DIR" 2>/dev/null
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

# Checks <dir>'s gitwt.sh and _gitwt are really gitwt's files.
check_files() {
  grep -q '^gitwt() {' "$1/gitwt.sh" || fail "$1/gitwt.sh isn't gitwt. $2"
  grep -q '^#compdef gitwt' "$1/_gitwt" || fail "$1/_gitwt isn't gitwt's completion file. $2"
}

# Sets SOURCE_DIR: a clone, if gitwt.sh and _gitwt sit next to this script (followed
# through symlinks), else a temporary folder with the files downloaded for <ref>.
# Piped through bash, there's no script file, so they're always downloaded.
find_source() {
  local ref="$1" script f
  SOURCE_DIR=""
  script="${BASH_SOURCE[0]:-}"
  # Run as a file, bash sets $0 to it. Piped, $0 is "bash" and BASH_SOURCE can be a
  # name like "main", which may match a file in the current folder.
  if [[ -n "$script" && "$script" == "$0" && -f "$script" ]]; then
    script="$(resolve_link "$script")"
    SOURCE_DIR="$(cd "$(dirname "$script")" && pwd)"
    for f in "${FILES[@]}"; do
      [[ -f "$SOURCE_DIR/$f" ]] || SOURCE_DIR=""
    done
  fi

  if [[ -n "$SOURCE_DIR" ]]; then
    echo "From: $SOURCE_DIR"
    check_files "$SOURCE_DIR" "Nothing was installed."
  else
    echo "From: $RAW_URL"
    TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/gitwt-install.XXXXXX")" || fail "could not create a temporary folder."
    for f in "${FILES[@]}"; do
      fetch "$RAW_URL/$f" "$TMP_DIR/$f" \
        || fail "could not download $f from $RAW_URL. Check your connection, and that '$ref' is a gitwt branch or tag."
    done
    # A failed download can still leave an error page
    check_files "$TMP_DIR" "Nothing was installed."
    SOURCE_DIR="$TMP_DIR"
  fi
  echo ""
}

# ── files ──────────────────────────────────────────────────────────────────────

# One install at a time, so two at once can't both add the shell config lines.
take_lock() {
  local lock="$INSTALL_DIR/.install-lock" tries=0 pid
  until mkdir "$lock" 2>/dev/null; do
    # Left behind by an install that was killed: take it over
    pid="$(cat "$lock/pid" 2>/dev/null || true)"
    if [[ -n "$pid" ]] && ! kill -0 "$pid" 2>/dev/null; then
      rm -f "$lock/pid"; rmdir "$lock" 2>/dev/null || true
      continue
    fi
    (( ++tries < 15 )) || fail "another install seems to be running ($lock exists). If none is, delete that folder and run this again."
    sleep 1
  done
  LOCK_DIR="$lock"
  echo "$$" > "$lock/pid"
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
    elif [[ -L "$dest" && -e "$dest" ]]; then
      yellow "  $f: a link to $(readlink "$dest"), left as is. To update it, update that copy, or delete the link and run this again."
    elif (( clone )); then
      yellow "  $f: part of a git clone, left as is. To update it: git -C $(shell_quote "$INSTALL_DIR") pull"
    else
      existed=0
      [[ -e "$dest" ]] && existed=1
      # Copy next to it, then rename over it: works even when the old file is read-only
      # (A link to nothing, say to a deleted clone, is replaced too.)
      PARTIAL="$dest.new.$$"
      cp "$src" "$PARTIAL" || fail "could not write to $INSTALL_DIR."
      mv -f "$PARTIAL" "$dest" || fail "could not replace $dest."
      PARTIAL=""
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

# Prints <file> with its quoted text made inert: quote marks are dropped, and inside
# quotes, the characters that could start a command or a comment (; & | ( ) # < >
# space tab) become _. So "$HOME/.config/gitwt/gitwt.sh" still reads as that path,
# while echo "tip; source ~/..." or alias x='cd; source ~/...' can't pass for a
# command, and PS1="#> " can't pass for a comment.
quotes_inert() {
  awk -v sq="'" '{
    out = ""; q = ""; n = length($0)
    for (i = 1; i <= n; i++) {
      c = substr($0, i, 1)
      if (q == "") {
        if (c == "\\") { out = out c substr($0, i + 1, 1); i++ }
        else if (c == "\"" || c == sq) { q = c }
        else { out = out c }
      } else if (c == q) { q = "" }
      else if (q == "\"" && c == "\\") { out = out "__"; i++ }
      else if (index(";&|()#<> \t", c)) { out = out "_" }
      else { out = out c }
    }
    print out
  }' "$1"
}

# Whether <file> has an active line that sources the installed <name>
# (~/.config/gitwt/<name>), written any common way: ~/, $HOME/, ${HOME}/, the full
# path, $XDG_CONFIG_HOME/ or ${XDG_CONFIG_HOME:-$HOME/.config}/; with `source` or `.`
# (optionally after builtin, command or --); quoted or not; at the start of the line,
# after ; && || { ( or after if, then, else, while and the like. Commented-out lines
# don't count, nor does a gitwt.sh somewhere else, nor text inside quotes.
has_source_line() {
  local file="$1" name_re home_re homes_re dir_re pfx_re kw_re re
  [[ -f "$file" ]] || return 1
  name_re="$(re_escape "$2")"
  # A quoted full path has its spaces and the like turned to _, so match it that way
  home_re="$(re_escape "$(printf '%s' "$HOME" | sed 's/[;&|()#<> 	]/_/g')")"
  homes_re='(~|\$HOME|\$\{HOME\}|'"$home_re"')'
  dir_re="$homes_re/\\.config"
  if [[ -z "${XDG_CONFIG_HOME:-}" || "${XDG_CONFIG_HOME%/}" == "$HOME/.config" ]]; then
    dir_re='('"$dir_re"'|\$XDG_CONFIG_HOME|\$\{XDG_CONFIG_HOME\}|\$\{XDG_CONFIG_HOME:?-'"$homes_re"'/\.config\})'
  fi
  # Text before the command, with no comment in it: a # starts a comment only at the
  # start of a word, so ${#x} is fine.
  pfx_re='([^#]*[^#[:space:];]#)*[^#]*'
  kw_re='((then|do|else|if|elif|while|until|!|builtin|command)[[:space:]]+)*'
  re='^[[:space:]]*('"$pfx_re"'[;&|({][[:space:]]*)?'"$kw_re"
  re+='(source|\.)[[:space:]]+(--[[:space:]]+)?'"$dir_re/gitwt/$name_re"'([[:space:];&|)<>]|$)'
  # (No grep -q: stopping early would make awk fail under pipefail.)
  quotes_inert "$file" | grep -E "$re" >/dev/null
}

# zsh reads its config from $ZDOTDIR, which is often set only in ~/.zshenv, where the
# bash running this can't see it. Ask zsh.
find_zdotdir() {
  local z="" rc=0
  if [[ -n "${ZDOTDIR:-}" ]]; then
    z="$ZDOTDIR"
  elif command -v zsh >/dev/null 2>&1; then
    # Only what's written to fd 3 is kept, so whatever ~/.zshenv prints is ignored
    z="$(zsh -c 'printf %s "${ZDOTDIR:-}" >&3' 3>&1 >/dev/null 2>&1 </dev/null)" || rc=$?
    (( rc <= 128 )) || exit "$rc"   # interrupted
    [[ "$z" == /* ]] || z=""
  fi
  printf '%s' "${z:-$HOME}"
}

# Whether the system's zshrc already runs compinit (Debian and Ubuntu's does).
global_compinit() {
  grep -Eqs '^[^#]*compinit' /etc/zsh/zshrc /etc/zshrc
}

# Appends the line that loads <name> to <file>. In ~/.profile, which sh reads too, it
# only loads in bash.
add_line() {
  local file="$1" name="$2" line
  line="source \"\$HOME/.config/gitwt/$name\""
  [[ "${file##*/}" == .profile ]] && line="[ -n \"\$BASH_VERSION\" ] && . \"\$HOME/.config/gitwt/$name\""
  printf '\n# gitwt — git worktree helper\n%s\n' "$line" >> "$file" || fail "could not write to $file."
  green "  $file: added a line to load $name"
}

# zsh: gitwt.sh and _gitwt load from <zshrc> (created if missing), which every
# interactive zsh reads, after compinit.
wire_zsh() {
  local rc="$1" profile="$2" name missing=()
  for name in gitwt.sh _gitwt; do
    if has_source_line "$rc" "$name"; then
      green "  $rc: already loads $name"
    else
      missing+=("$name")
    fi
  done
  (( ${#missing[@]} )) || return 0

  if [[ ! -f "$rc" ]]; then
    mkdir -p "$(dirname "$rc")" || fail "could not create $rc."
    if global_compinit; then
      : > "$rc" || fail "could not create $rc."
    else
      # zsh's tab-completion needs compinit, which a new .zshrc doesn't run
      printf '# Turn on zsh tab-completion\nautoload -Uz compinit && compinit\n' > "$rc" \
        || fail "could not create $rc."
    fi
    yellow "  Created $rc, since there was none."
  fi

  for name in "${missing[@]}"; do add_line "$rc" "$name"; done

  # An older installer wrote to .zprofile on macOS. That runs before .zshrc's compinit
  # (so no completion) and only in login shells; .zshrc now does the job.
  if has_source_line "$profile" gitwt.sh || has_source_line "$profile" _gitwt; then
    yellow "  Note: $profile also loads gitwt, probably from an older install. $rc does that now; you can delete the gitwt lines from $profile."
  fi

  if [[ " ${missing[*]} " == *" _gitwt "* ]] && ! global_compinit \
    && ! grep -Eq 'compinit|oh-my-zsh|prezto|zimfw|zinit|antidote|antigen|zplug' "$rc"; then
    yellow "  Note: $rc doesn't seem to run compinit, so zsh tab-completion stays off. To turn it on, add this before the gitwt lines:"
    yellow "    autoload -Uz compinit && compinit"
  fi
}

# bash: gitwt.sh loads from <bashrc> (created if missing), which terminals on Linux
# read. Terminals on macOS start login shells, which read the first of .bash_profile,
# .bash_login and .profile instead; that file gets the line too, unless it already
# reads .bashrc.
wire_bash() {
  local rc="$1" create_login="$2" login="" f
  if has_source_line "$rc" gitwt.sh; then
    green "  $rc: already loads gitwt.sh"
  else
    if [[ ! -f "$rc" ]]; then
      : > "$rc" || fail "could not create $rc."
      yellow "  Created $rc, since there was none."
    fi
    add_line "$rc" gitwt.sh
  fi

  for f in .bash_profile .bash_login .profile; do
    if [[ -f "$HOME/$f" ]]; then login="$HOME/$f"; break; fi
  done
  if [[ -z "$login" ]]; then
    (( create_login )) || return 0
    login="$HOME/.bash_profile"
    : > "$login" || fail "could not create $login."
    yellow "  Created $login, which login shells read, since there was none."
  fi
  if quotes_inert "$login" | grep -E '^[^#]*\.bashrc' >/dev/null; then
    return 0   # it reads .bashrc, which loads gitwt
  elif has_source_line "$login" gitwt.sh; then
    green "  $login: already loads gitwt.sh"
  else
    add_line "$login" gitwt.sh
  fi
}

# gitwt needs bash 4 or newer; macOS's /bin/bash is 3.2.
check_bash_version() {
  local v
  v="$("$SHELL" -c 'echo "${BASH_VERSINFO[0]}"' 2>/dev/null </dev/null || true)"
  if [[ "$v" =~ ^[0-9]+$ ]] && (( v < 4 )); then
    yellow "Note: your shell is bash $v, but gitwt needs zsh or bash 4 or newer. macOS's own"
    yellow "bash is 3.2; switch to zsh (chsh -s /bin/zsh), or install a newer bash."
    echo ""
  fi
}

# Wires up the login shell if it's zsh or bash, creating its config if missing, and
# the other one if its config exists.
wire_shells() {
  local zdotdir zshrc bashrc shell darwin=0
  zdotdir="$(find_zdotdir)"
  zshrc="$zdotdir/.zshrc" bashrc="$HOME/.bashrc"
  WIRED_ZSHRC="" WIRED_BASHRC=""
  [[ "$(uname -s 2>/dev/null || true)" == Darwin ]] && darwin=1

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
  if [[ -n "$WIRED_ZSHRC" ]]; then wire_zsh "$zshrc" "$zdotdir/.zprofile"; fi
  if [[ -n "$WIRED_BASHRC" ]]; then
    # On macOS, a bash user's login shell needs a file to read even if there's none yet
    if (( darwin )) && [[ "$shell" == bash ]]; then wire_bash "$bashrc" 1; else wire_bash "$bashrc" 0; fi
  fi
  echo ""
  if [[ "$shell" == bash ]]; then check_bash_version; fi
}

# ── done ───────────────────────────────────────────────────────────────────────

finish() {
  local version
  version="$(sed -n 's/^ *local GITWT_VERSION="\([^"]*\)".*/\1/p' "$INSTALL_DIR/gitwt.sh" 2>/dev/null | head -1 || true)"
  bold "==> gitwt ${version:-?} is installed"
  echo ""
  echo "Open a new terminal, or load it in this one:"
  if [[ -n "$WIRED_ZSHRC" ]]; then echo "  source $(shell_quote "$WIRED_ZSHRC")    # in zsh"; fi
  if [[ -n "$WIRED_BASHRC" ]]; then echo "  source $(shell_quote "$WIRED_BASHRC")    # in bash"; fi
  echo ""
  echo "Then try:  gitwt help"
}

main "$@"
