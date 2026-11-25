#!/usr/bin/env bash
# Runs a setup script twice in a throwaway container, then checks the home directory.
# Usage, as root in a fresh Debian or Ubuntu container with the repo mounted read-only:
#   bash tests/container.sh <ssh|wsl|desktop> <root|sudo|nosudo>
set -u
flavor="$1"
mode="$2"
repo="$(cd "$(dirname "$0")/.." && pwd)"
case "$flavor" in
  desktop) script="$repo/setup-terminal.sh" ;;
  ssh | wsl) script="$repo/setup-terminal-$flavor.sh" ;;
  *) echo "unknown flavor: $flavor"; exit 2 ;;
esac
export DEBIAN_FRONTEND=noninteractive

prepare() {
  apt-get update -qq
  apt-get install -y -qq "$@" >/dev/null
}

case "$mode" in
  root)
    user=root
    ;;
  sudo)
    prepare sudo
    useradd -m -s /bin/bash tester
    printf '%s\n' 'tester ALL=(ALL) NOPASSWD: ALL' 'Defaults env_keep += "DEBIAN_FRONTEND"' > /etc/sudoers.d/tester
    user=tester
    ;;
  nosudo)
    # A server where someone else installed the basics but the user cannot run apt
    prepare ca-certificates curl git zsh tmux
    useradd -m -s /bin/bash tester
    user=tester
    ;;
  *) echo "unknown mode: $mode"; exit 2 ;;
esac
if [ "$flavor" = desktop ]; then
  prepare fontconfig xz-utils software-properties-common
fi

home="$(getent passwd "$user" | cut -d: -f6)"
# GITHUB_TOKEN, when the CI passes one, lifts the GitHub API rate limit
as_user() { su - "$user" -w GITHUB_TOKEN -c "export DEBIAN_FRONTEND=noninteractive; $1"; }

# Seed an old zsh history to check the one-time atuin import
as_user "printf ': 1700000000:0;echo history-from-zsh\n' > ~/.zsh_history"

run_setup() {
  echo "::group::$flavor, $mode, run $1"
  as_user "bash $script" 2>&1 | tee "/tmp/run$1.log"
  echo "::endgroup::"
  grep -F '[!!]' "/tmp/run$1.log" | sed "s/^/::warning::run $1: /"
}
backups() { find "$home" -name '*.bak-*' | wc -l; }

fails=0
run_setup 1
after_first="$(backups)"
run_setup 2
after_second="$(backups)"
if [ "$after_first" -ne "$after_second" ]; then
  echo "::error::second run backed up files that did not change ($after_first then $after_second backups)"
  find "$home" -name '*.bak-*'
  fails=1
fi

as_user "bash $repo/tests/check.sh $repo" || fails=1
exit "$fails"
