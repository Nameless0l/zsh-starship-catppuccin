#!/usr/bin/env bash
# Checks the current user's home after a setup script ran.
# Usage: bash tests/check.sh <repo>
set -u
repo="$1"
export PATH="$HOME/.local/bin:$PATH"
fails=0
pass() { echo "ok    $1"; }
fail() { echo "::error::$1"; fails=$((fails + 1)); }
check() {
  if [ "$1" = "$2" ]; then pass "$3"; else fail "$3: expected '$2', got '$1'"; fi
}
same() {
  if cmp -s "$repo/$1" "$2"; then pass "$2"; else fail "$2 is missing or differs from $1"; fi
}
has() { command -v "$1" >/dev/null 2>&1; }
# zsh under a pseudo terminal, like a real session
zsh_i() { script -qec "zsh -i -c '$1'" /dev/null | tr -d '\r'; }

same config/zshrc "$HOME/.zshrc"
same config/starship.toml "$HOME/.config/starship.toml"
same config/lazygit.yml "$HOME/.config/lazygit/config.yml"
same eza/theme.yml "$HOME/.config/eza/theme.yml"

for tool in zsh starship atuin tldr; do
  if has "$tool"; then pass "$tool installed"; else fail "$tool not installed"; fi
done

if has zsh; then
  check "$(zsh_i 'exit' 2>&1)" "" "zsh starts without output"
  check "$(zsh_i 'bindkey "^I"')" '"^I" fzf-tab-complete' "Tab opens fzf-tab"
  if has atuin; then
    check "$(zsh_i 'bindkey "^R"')" '"^R" atuin-search' "Ctrl+R opens atuin"
  fi
  check "$(zsh_i 'whence -w ls')" "ls: alias" "ls alias"
  if has zoxide; then
    # zoxide defines cd as an alias or a function depending on its version
    if [ "$(zsh_i 'whence -w cd')" != "cd: builtin" ]; then pass "cd goes through zoxide"; else fail "cd is still the builtin"; fi
  fi
  if has tmux; then
    check "$(zsh_i 'whence -w t')" "t: alias" "t alias for tmux"
  fi
fi

if has starship; then
  check "$(cd /tmp && starship prompt 2>&1 >/dev/null)" "" "starship prompt without warnings"
fi

if has eza; then
  d="$(mktemp -d)"
  mkdir "$d/src"
  touch "$d/Cargo.toml" "$d/package.json" "$d/main.rs"
  themed="$(LS_COLORS='' eza --icons=always --color=always "$d" </dev/null)"
  plain="$(LS_COLORS='' EZA_CONFIG_DIR=/nonexistent eza --icons=always --color=always "$d" </dev/null)"
  if [ "$themed" != "$plain" ]; then pass "eza theme applied"; else fail "eza theme has no effect"; fi
  rm -rf "$d"
fi

if has tmux; then
  same config/tmux.conf "$HOME/.config/tmux/tmux.conf"
  if tmux -L ci new-session -d -s ci && tmux -L ci source-file "$HOME/.config/tmux/tmux.conf"; then
    check "$(tmux -L ci show -gv @catppuccin_flavor)" "mocha" "tmux Catppuccin flavor"
    check "$(tmux -L ci show -gv @thm_bg)" "#1e1e2e" "tmux Catppuccin theme loaded"
  else
    fail "tmux.conf has errors"
  fi
  tmux -L ci kill-server 2>/dev/null
fi

if has atuin; then
  same config/atuin/config.toml "$HOME/.config/atuin/config.toml"
  same config/atuin/themes/catppuccin-mocha-mauve.toml "$HOME/.config/atuin/themes/catppuccin-mocha-mauve.toml"
  check "$(ATUIN_SESSION="$(atuin uuid)" atuin search --cmd-only 'history-from-zsh' 2>&1)" "echo history-from-zsh" "zsh history imported into atuin"
fi

if has tldr; then
  same config/tealdeer.toml "$HOME/.config/tealdeer/config.toml"
  if tldr --color always tar 2>&1 | grep -q '38;2;203;166;247m'; then
    pass "tldr pages with Catppuccin colors"
  else
    fail "tldr tar did not print a page in Catppuccin colors"
  fi
fi

if has delta; then
  check "$(git config --global core.pager)" "delta" "git uses delta"
fi

[ "$fails" -eq 0 ] && echo "all checks passed"
exit "$fails"
