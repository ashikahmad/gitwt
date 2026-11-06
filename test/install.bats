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
  for tool in bash cat grep sed mktemp rm mkdir cp mv cmp head dirname tr; do
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
