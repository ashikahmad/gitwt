#!/usr/bin/env bats

# install.sh, run with a throwaway HOME. Downloads go to a fake curl that serves this
# repo's own files and logs each URL, so nothing touches the network.

load 'test_helper'

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  T="$(mktemp -d)"
  export HOME="$T/home"
  mkdir -p "$HOME" "$T/bin"
  unset ZDOTDIR
  export SHELL=/bin/zsh
  printf '#!/bin/sh\n# fake curl: -fsSL <url> -o <file>\nurl=""; out=""\nwhile [ $# -gt 0 ]; do case "$1" in -o) out="$2"; shift 2 ;; -*) shift ;; *) url="$1"; shift ;; esac; done\necho "$url" >> "%s/urls"\n[ -n "${FAKE_CURL_FAIL:-}" ] && exit 22\n[ -n "${FAKE_CURL_HTML:-}" ] && { echo "<html>404</html>" > "$out"; exit 0; }\ncp "%s/${url##*/}" "$out"\n' "$T" "$REPO_ROOT" > "$T/bin/curl"
  chmod +x "$T/bin/curl"
}
teardown() { rm -rf "$T"; }

# Runs install.sh the one-line way: piped into bash, with the fake curl, from a folder
# that has nothing to do with gitwt, as a real one-liner would.
install_piped() {
  run env PATH="$T/bin:$PATH" bash -c "cd '$T' && cat '$REPO_ROOT/install.sh' | bash"
}

# Runs install.sh from the clone.
install_from_clone() {
  run bash "$REPO_ROOT/install.sh"
}

@test "install: the version in install.sh matches gitwt.sh" {
  local a b
  a="$(sed -n 's/^GITWT_VERSION="\(.*\)"/\1/p' "$REPO_ROOT/install.sh")"
  b="$(sed -n 's/^ *local GITWT_VERSION="\(.*\)"/\1/p' "$REPO_ROOT/gitwt.sh")"
  [[ -n "$a" ]]
  assert_equal "$a" "$b"
}

@test "install: piped into bash, downloads from the version tag and installs" {
  printf '# my zshrc\n' > "$HOME/.zshrc"
  install_piped
  assert_success
  local v; v="$(sed -n 's/^GITWT_VERSION="\(.*\)"/\1/p' "$REPO_ROOT/install.sh")"
  assert_output --partial "gitwt $v is installed"
  run cat "$T/urls"
  assert_line "https://raw.githubusercontent.com/ashikahmad/gitwt/v$v/gitwt.sh"
  assert_line "https://raw.githubusercontent.com/ashikahmad/gitwt/v$v/_gitwt"
  cmp -s "$REPO_ROOT/gitwt.sh" "$HOME/.config/gitwt/gitwt.sh"
  cmp -s "$REPO_ROOT/_gitwt" "$HOME/.config/gitwt/_gitwt"
  grep -qxF 'source "$HOME/.config/gitwt/gitwt.sh"' "$HOME/.zshrc"
  grep -qxF 'source "$HOME/.config/gitwt/_gitwt"' "$HOME/.zshrc"
}

@test "install: GITWT_REF picks the branch or tag to download" {
  : > "$HOME/.zshrc"
  run env PATH="$T/bin:$PATH" GITWT_REF=main bash -c "cd '$T' && cat '$REPO_ROOT/install.sh' | bash"
  assert_success
  run cat "$T/urls"
  assert_line "https://raw.githubusercontent.com/ashikahmad/gitwt/main/gitwt.sh"
}

@test "install: from a clone, copies the files without downloading" {
  : > "$HOME/.bashrc"
  install_from_clone
  assert_success
  assert_output --partial "From: $REPO_ROOT"
  [[ ! -e "$T/urls" ]]
  cmp -s "$REPO_ROOT/gitwt.sh" "$HOME/.config/gitwt/gitwt.sh"
  grep -qxF 'source "$HOME/.config/gitwt/gitwt.sh"' "$HOME/.bashrc"
}

@test "install: running again adds nothing twice and says it's up to date" {
  : > "$HOME/.zshrc"; : > "$HOME/.bashrc"
  install_piped
  install_piped
  assert_success
  assert_output --partial "gitwt.sh: already up to date"
  assert_output --partial "already loads gitwt.sh"
  assert_equal "$(grep -c 'gitwt/gitwt.sh' "$HOME/.zshrc")" "1"
  assert_equal "$(grep -c 'gitwt/_gitwt' "$HOME/.zshrc")" "1"
  assert_equal "$(grep -c 'gitwt/gitwt.sh' "$HOME/.bashrc")" "1"
}

@test "install: an older install is updated" {
  : > "$HOME/.zshrc"
  mkdir -p "$HOME/.config/gitwt"
  echo "old" > "$HOME/.config/gitwt/gitwt.sh"
  install_piped
  assert_success
  assert_output --partial "gitwt.sh: updated"
  cmp -s "$REPO_ROOT/gitwt.sh" "$HOME/.config/gitwt/gitwt.sh"
}

@test "install: read-only installed files are still replaced (TASK-022)" {
  [[ "$(id -u)" != 0 ]] || skip "root can overwrite read-only files anyway, so this can't tell"
  : > "$HOME/.zshrc"
  mkdir -p "$HOME/.config/gitwt"
  echo "old" > "$HOME/.config/gitwt/gitwt.sh"; echo "old" > "$HOME/.config/gitwt/_gitwt"
  chmod 444 "$HOME/.config/gitwt/gitwt.sh" "$HOME/.config/gitwt/_gitwt"
  install_piped
  assert_success
  cmp -s "$REPO_ROOT/gitwt.sh" "$HOME/.config/gitwt/gitwt.sh"
}

@test "install: a clone at ~/.config/gitwt is left as is and still wired up (TASK-022)" {
  : > "$HOME/.zshrc"
  mkdir -p "$HOME/.config"
  cp -R "$REPO_ROOT" "$HOME/.config/gitwt"
  run bash "$HOME/.config/gitwt/install.sh"
  assert_success
  assert_output --partial "gitwt.sh: already the same file"
  grep -qxF 'source "$HOME/.config/gitwt/gitwt.sh"' "$HOME/.zshrc"
}

@test "install: files symlinked to a clone are left as is (TASK-022)" {
  : > "$HOME/.zshrc"
  mkdir -p "$HOME/.config/gitwt"
  ln -s "$REPO_ROOT/gitwt.sh" "$HOME/.config/gitwt/gitwt.sh"
  ln -s "$REPO_ROOT/_gitwt" "$HOME/.config/gitwt/_gitwt"
  install_from_clone
  assert_success
  assert_output --partial "already the same file"
  [[ -L "$HOME/.config/gitwt/gitwt.sh" ]]
}

@test "install: recognises existing source lines written another way (TASK-022)" {
  printf 'source ~/.config/gitwt/gitwt.sh\n. "$HOME/.config/gitwt/_gitwt"\n' > "$HOME/.zshrc"
  printf '[ -f ~/.config/gitwt/gitwt.sh ] && source ~/.config/gitwt/gitwt.sh\n' > "$HOME/.bashrc"
  install_piped
  assert_success
  assert_equal "$(grep -c 'gitwt' "$HOME/.zshrc")" "2"
  assert_equal "$(grep -c 'gitwt' "$HOME/.bashrc")" "1"
}

@test "install: a commented-out line doesn't count as installed (TASK-022)" {
  printf '# source "$HOME/.config/gitwt/gitwt.sh"\n' > "$HOME/.zshrc"
  install_piped
  assert_success
  assert_output --partial "added a line to load gitwt.sh"
  grep -qxF 'source "$HOME/.config/gitwt/gitwt.sh"' "$HOME/.zshrc"
}

@test "install: with no shell config, creates one for the login shell (TASK-008)" {
  install_piped
  assert_success
  assert_output --partial "Created $HOME/.zshrc"
  grep -qxF 'source "$HOME/.config/gitwt/gitwt.sh"' "$HOME/.zshrc"
  [[ ! -e "$HOME/.bashrc" ]]

  rm -f "$HOME/.zshrc"
  SHELL=/bin/bash install_piped
  assert_success
  grep -qxF 'source "$HOME/.config/gitwt/gitwt.sh"' "$HOME/.bashrc"
}

@test "install: with no shell config and another shell, fails and says what to add (TASK-008)" {
  SHELL=/usr/bin/fish install_piped
  assert_failure 1
  assert_output --partial "isn't zsh or bash"
  assert_output --partial 'source "$HOME/.config/gitwt/gitwt.sh"'
  refute_output --partial "is installed"
}

@test "install: respects ZDOTDIR" {
  mkdir -p "$T/zdot"; : > "$T/zdot/.zshrc"
  run env PATH="$T/bin:$PATH" ZDOTDIR="$T/zdot" bash -c "cd '$T' && cat '$REPO_ROOT/install.sh' | bash"
  assert_success
  grep -qxF 'source "$HOME/.config/gitwt/gitwt.sh"' "$T/zdot/.zshrc"
  [[ ! -e "$HOME/.zshrc" ]]
}

@test "install: a failed download installs nothing" {
  : > "$HOME/.zshrc"
  mkdir -p "$HOME/.config/gitwt"; echo "old" > "$HOME/.config/gitwt/gitwt.sh"
  run env PATH="$T/bin:$PATH" FAKE_CURL_FAIL=1 bash -c "cd '$T' && cat '$REPO_ROOT/install.sh' | bash"
  assert_failure 1
  assert_output --partial "could not download gitwt.sh"
  assert_equal "$(cat "$HOME/.config/gitwt/gitwt.sh")" "old"
  [[ ! -s "$HOME/.zshrc" ]]
}

@test "install: an error page instead of the script installs nothing" {
  : > "$HOME/.zshrc"
  run env PATH="$T/bin:$PATH" FAKE_CURL_HTML=1 bash -c "cd '$T' && cat '$REPO_ROOT/install.sh' | bash"
  assert_failure 1
  assert_output --partial "isn't gitwt"
  [[ ! -e "$HOME/.config/gitwt/gitwt.sh" ]]
}

@test "install: uses wget when there's no curl" {
  : > "$HOME/.zshrc"
  sed 's/-o) out="$2"; shift 2/-O) out="$2"; shift 2/' "$T/bin/curl" > "$T/bin/wget"
  chmod +x "$T/bin/wget"; rm "$T/bin/curl"
  mkdir -p "$T/nocurl"
  for tool in bash cat grep sed mktemp rm rmdir mkdir cp mv cmp head dirname tr sleep readlink; do
    ln -s "$(command -v "$tool")" "$T/nocurl/$tool"
  done
  run env PATH="$T/bin:$T/nocurl" bash -c "cd '$T' && cat '$REPO_ROOT/install.sh' | bash"
  assert_success
  cmp -s "$REPO_ROOT/gitwt.sh" "$HOME/.config/gitwt/gitwt.sh"
}

@test "install: a new zsh can use gitwt afterwards, without a completion error (TASK-014)" {
  command -v zsh >/dev/null || skip "zsh not installed"
  printf 'PS1="> "\n' > "$HOME/.zshrc"
  install_piped
  assert_success
  local v; v="$(sed -n 's/^GITWT_VERSION="\(.*\)"/\1/p' "$REPO_ROOT/install.sh")"
  run env HOME="$HOME" zsh -c 'source ~/.zshrc; gitwt version'
  assert_success
  assert_output "gitwt $v"
}

# ── review findings on PR #10 ──────────────────────────────────────────────────

@test "install: a zsh user with only a .bashrc gets zsh wired up too" {
  : > "$HOME/.bashrc"
  install_piped
  assert_success
  assert_output --partial "Created $HOME/.zshrc"
  grep -qxF 'source "$HOME/.config/gitwt/gitwt.sh"' "$HOME/.zshrc"
  grep -qxF 'source "$HOME/.config/gitwt/_gitwt"' "$HOME/.zshrc"
  grep -qxF 'source "$HOME/.config/gitwt/gitwt.sh"' "$HOME/.bashrc"
}

@test "install: a bash user with only a .zshrc gets bash wired up too" {
  : > "$HOME/.zshrc"
  SHELL=/bin/bash install_piped
  assert_success
  grep -qxF 'source "$HOME/.config/gitwt/gitwt.sh"' "$HOME/.bashrc"
  grep -qxF 'source "$HOME/.config/gitwt/gitwt.sh"' "$HOME/.zshrc"
}

@test "install: a .zshrc it creates turns on completion, before the gitwt lines" {
  command -v zsh >/dev/null || skip "zsh not installed"
  install_piped
  assert_success
  local c g
  c="$(grep -n 'compinit' "$HOME/.zshrc" | head -1 | cut -d: -f1)"
  g="$(grep -n 'gitwt/_gitwt' "$HOME/.zshrc" | cut -d: -f1)"
  [[ -n "$c" && "$c" -lt "$g" ]]
  refute_output --partial "doesn't seem to run compinit"
  run env HOME="$HOME" zsh -c 'source ~/.zshrc; (( $+_comps[gitwt] )) && echo completion-on'
  assert_success
  assert_output --partial "completion-on"
}

@test "install: says how to turn on completion when an existing .zshrc has no compinit" {
  printf 'PS1="> "\n' > "$HOME/.zshrc"
  install_piped
  assert_success
  assert_output --partial "doesn't seem to run compinit"

  rm -rf "$HOME/.config"
  printf 'autoload -Uz compinit && compinit\n' > "$HOME/.zshrc"
  install_piped
  assert_success
  refute_output --partial "doesn't seem to run compinit"
}

@test "install: an installed file that links somewhere else is left as a link" {
  : > "$HOME/.zshrc"
  mkdir -p "$HOME/.config/gitwt" "$T/elsewhere"
  echo "old" > "$T/elsewhere/gitwt.sh"
  ln -s "$T/elsewhere/gitwt.sh" "$HOME/.config/gitwt/gitwt.sh"
  install_piped
  assert_success
  assert_output --partial "gitwt.sh: a link to $T/elsewhere/gitwt.sh, left as is"
  [[ -L "$HOME/.config/gitwt/gitwt.sh" ]]
  assert_equal "$(cat "$T/elsewhere/gitwt.sh")" "old"
  # The other file, a plain one, is still installed
  cmp -s "$REPO_ROOT/_gitwt" "$HOME/.config/gitwt/_gitwt"
}

@test "install: a git clone at ~/.config/gitwt isn't overwritten by a download" {
  : > "$HOME/.zshrc"
  mkdir -p "$HOME/.config"
  cp -R "$REPO_ROOT" "$HOME/.config/gitwt"
  echo "old" > "$HOME/.config/gitwt/gitwt.sh"
  install_piped
  assert_success
  assert_output --partial "gitwt.sh: part of a git clone, left as is"
  assert_output --partial "git -C $HOME/.config/gitwt pull"
  assert_equal "$(cat "$HOME/.config/gitwt/gitwt.sh")" "old"
}

# Runs the installer with <line> as the only line of ~/.bashrc, then says whether it
# treated the line as already loading gitwt.
_recognises() {
  rm -rf "$HOME/.config"
  printf '%s\n' "$1" > "$HOME/.bashrc"
  run env PATH="$T/bin:$PATH" SHELL=/bin/bash bash -c "cd '$T' && cat '$REPO_ROOT/install.sh' | bash"
  [[ "$status" == 0 ]] || { echo "install failed for: $1"; echo "$output"; return 2; }
  [[ "$output" == *"already loads gitwt.sh"* ]]
}

@test "install: recognises source lines written in other working ways" {
  local line bad=()
  local lines=(
    '[[ -f ~/.config/gitwt/gitwt.sh ]] && . ~/.config/gitwt/gitwt.sh'
    'source ${HOME}/.config/gitwt/gitwt.sh'
    'source "$HOME"/.config/gitwt/gitwt.sh'
    'source "$HOME/.config/gitwt/gitwt.sh"   # gitwt'
    $'\tsource ~/.config/gitwt/gitwt.sh'
    'if [ -f ~/.config/gitwt/gitwt.sh ]; then source ~/.config/gitwt/gitwt.sh; fi'
    'PS1="#> "; source ~/.config/gitwt/gitwt.sh'
    'source ~/.config/gitwt/gitwt.sh&&true'
    'source $XDG_CONFIG_HOME/gitwt/gitwt.sh'
    "source \"$HOME/.config/gitwt/gitwt.sh\""
  )
  for line in "${lines[@]}"; do
    _recognises "$line" || bad+=("$line")
  done
  (( ${#bad[@]} == 0 )) || { printf 'not recognised: %s\n' "${bad[@]}"; false; }
}

@test "install: doesn't mistake other lines for one that loads gitwt" {
  local line bad=()
  local lines=(
    'source ~/work/othertool/gitwt.sh'
    'echo "run: source ~/.config/gitwt/gitwt.sh"'
    'source ~/.config/gitwt/gitwtXsh'
    'source ~/.config/gitwt/gitwt.sh.bak'
    '# source ~/.config/gitwt/gitwt.sh'
    '  # [[ -f x ]] && source ~/.config/gitwt/gitwt.sh'
  )
  local r
  for line in "${lines[@]}"; do
    _recognises "$line" && r=0 || r=$?
    [[ "$r" == 1 ]] || bad+=("$line")
  done
  (( ${#bad[@]} == 0 )) || { printf 'wrongly recognised: %s\n' "${bad[@]}"; false; }
}

@test "install: a download cut short does all of the install or none of it" {
  local size cut bad=()
  size="$(wc -c < "$REPO_ROOT/install.sh")"
  for (( cut = 200; cut < size; cut += 250 )); do
    rm -rf "$HOME/.config"; : > "$HOME/.zshrc"
    env PATH="$T/bin:$PATH" bash -c "cd '$T' && head -c $cut '$REPO_ROOT/install.sh' | bash" >/dev/null 2>&1 || true
    if [[ -e "$HOME/.config/gitwt/gitwt.sh" ]] && ! grep -q 'gitwt/_gitwt' "$HOME/.zshrc"; then
      bad+=("$cut")
    fi
  done
  (( ${#bad[@]} == 0 )) || { echo "half installed when cut at bytes: ${bad[*]}"; false; }
}

@test "install: piped into sh, says to use bash" {
  : > "$HOME/.zshrc"
  run env PATH="$T/bin:$PATH" sh -c "cd '$T' && cat '$REPO_ROOT/install.sh' | sh"
  assert_failure 1
  assert_output --partial "needs bash"
  [[ ! -e "$HOME/.config/gitwt" ]]
}

@test "install: run through a symlink to a clone's install.sh, uses the clone" {
  : > "$HOME/.zshrc"
  mkdir -p "$T/links"
  ln -s "$REPO_ROOT/install.sh" "$T/links/install.sh"
  run env PATH="$T/bin:$PATH" bash "$T/links/install.sh"
  assert_success
  assert_output --partial "From: $REPO_ROOT"
  [[ ! -e "$T/urls" ]]
}

@test "install: the hint to load the config is quoted when HOME has a space" {
  export HOME="$T/my home"
  mkdir -p "$HOME"; : > "$HOME/.zshrc"
  install_piped
  assert_success
  assert_output --partial "source $T/my\\ home/.zshrc"
}

@test "install: sourcing it refuses, and leaves the shell's options alone" {
  run bash -c "source '$REPO_ROOT/install.sh'; echo \"options: \$-\""
  assert_output --partial "don't source it"
  refute_output --regexp 'options: [a-zA-Z]*e'
  [[ ! -e "$HOME/.config/gitwt" ]]
}

@test "install: several installs at once add each line only once" {
  : > "$HOME/.zshrc"
  local i
  for i in 1 2 3 4; do
    env PATH="$T/bin:$PATH" bash -c "cd '$T' && cat '$REPO_ROOT/install.sh' | bash" >/dev/null 2>&1 &
  done
  wait
  assert_equal "$(grep -c 'gitwt/gitwt.sh' "$HOME/.zshrc")" "1"
  assert_equal "$(grep -c 'gitwt/_gitwt' "$HOME/.zshrc")" "1"
  [[ ! -e "$HOME/.config/gitwt/.install-lock" ]]
}

@test "install: finds ZDOTDIR set in ~/.zshenv" {
  command -v zsh >/dev/null || skip "zsh not installed"
  printf 'export ZDOTDIR="$HOME/zdot"\n' > "$HOME/.zshenv"
  install_piped
  assert_success
  grep -qxF 'source "$HOME/.config/gitwt/gitwt.sh"' "$HOME/zdot/.zshrc"
  [[ ! -e "$HOME/.zshrc" ]]
}

@test "install: lines an older install put in .zprofile count, so they aren't loaded twice" {
  printf 'source "%s/.config/gitwt/gitwt.sh"\nsource "%s/.config/gitwt/_gitwt"\n' "$HOME" "$HOME" > "$HOME/.zprofile"
  install_piped
  assert_success
  assert_output --partial "$HOME/.zprofile: already loads gitwt.sh"
  [[ ! -e "$HOME/.zshrc" ]]
  assert_output --partial "Open a new terminal to start using it."
  refute_output --partial "source $HOME/.zshrc"
}

@test "install: the guide's by-hand steps download this version's tag" {
  local v; v="$(sed -n 's/^GITWT_VERSION="\(.*\)"/\1/p' "$REPO_ROOT/install.sh")"
  run grep -c "raw.githubusercontent.com/ashikahmad/gitwt/v$v/" "$REPO_ROOT/docs/usage.md"
  assert_output "2"
  run grep -E 'raw.githubusercontent.com/ashikahmad/gitwt/main/(gitwt\.sh|_gitwt)' "$REPO_ROOT/docs/usage.md"
  assert_failure
}
