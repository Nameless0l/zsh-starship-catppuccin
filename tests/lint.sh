#!/usr/bin/env bash
# Static checks: bash and zsh syntax, shellcheck, TOML files, line endings.
set -u
cd "$(dirname "$0")/.." || exit 1
fails=0
fail() { echo "::error::$1"; fails=$((fails + 1)); }

for f in setup-terminal*.sh eza/build.sh tests/*.sh; do
  bash -n "$f" || fail "bash syntax: $f"
done
zsh -n config/zshrc || fail "zsh syntax: config/zshrc"

# SC2088: section titles print ~ on purpose
shellcheck -e SC2088 setup-terminal*.sh eza/build.sh tests/*.sh || fail "shellcheck"

for f in config/*.toml config/atuin/*.toml config/atuin/themes/*.toml; do
  python3 -c 'import sys, tomllib; tomllib.load(open(sys.argv[1], "rb"))' "$f" || fail "invalid TOML: $f"
done

# Windows PowerShell 5.1 reads the Windows script as ANSI, where these UTF-8 bytes become quote characters
python3 - setup-terminal-windows.ps1 << 'EOF' || fail "setup-terminal-windows.ps1 has characters that Windows PowerShell 5.1 misreads"
import sys
data = open(sys.argv[1], "rb").read()
sys.exit(bool(set(data) & {0x82, 0x84, 0x91, 0x92, 0x93, 0x94}))
EOF

if command -v pwsh >/dev/null; then
  pwsh -NoProfile -File tests/lint.ps1 || fail "PowerShell syntax or PSScriptAnalyzer"
else
  echo "pwsh missing, PowerShell files not checked"
fi

crlf="$(git grep -lI $'\r' -- . || true)"
[ -z "$crlf" ] || fail "CRLF line endings: $crlf"

[ "$fails" -eq 0 ] && echo "lint ok"
exit "$fails"
