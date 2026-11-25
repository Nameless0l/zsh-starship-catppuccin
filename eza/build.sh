#!/usr/bin/env bash
# Régénère eza/theme.yml à partir des sources de Material Icon Theme et de Nerd Fonts.
# Usage : bash eza/build.sh
# Les fichiers téléchargés vont dans un dossier temporaire, lus comme simples données.
set -e

ICI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIT="https://codeload.github.com/material-extensions/vscode-material-icon-theme/tar.gz/refs/heads/main"
# Version minimale de Nerd Fonts visée : le thème n'utilise que des glyphes présents en 3.3.0
NF="https://raw.githubusercontent.com/ryanoasis/nerd-fonts/v3.3.0/glyphnames.json"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/mit"

telecharger() {
  curl -fsSL --retry 5 --retry-delay 2 --retry-all-errors -o "$1" "$2"
}

echo "Téléchargement de Material Icon Theme et des noms de glyphes Nerd Fonts"
telecharger "$tmp/mit.tar.gz" "$MIT"
tar -xzf "$tmp/mit.tar.gz" -C "$tmp/mit" --strip-components=1 --wildcards '*/src/core/*' '*/icons/*'
telecharger "$tmp/glyphnames.json" "$NF"

python3 -I "$ICI/parse_material.py" "$tmp/mit" "$tmp/material_map.json"
python3 -I "$ICI/gen_theme.py" "$tmp/material_map.json" "$tmp/mit/icons" "$tmp/glyphnames.json" "$ICI/theme.yml"
echo "Écrit : $ICI/theme.yml"
