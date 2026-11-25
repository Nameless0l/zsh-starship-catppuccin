#!/usr/bin/env bash
# Régénère eza/theme.yml à partir des sources de Material Icon Theme et de Nerd Fonts.
# Usage : bash eza/build.sh
# Les fichiers téléchargés vont dans un dossier temporaire, lus comme simples données.
set -e

ICI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIT="https://raw.githubusercontent.com/material-extensions/vscode-material-icon-theme/main"
# Version minimale de Nerd Fonts visée : le thème n'utilise que des glyphes présents en 3.3.0
NF="https://raw.githubusercontent.com/ryanoasis/nerd-fonts/v3.3.0/glyphnames.json"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/svg"

telecharger() {
  curl -fsSL --retry 5 --retry-delay 2 --retry-all-errors -o "$1" "$2"
}

echo "Téléchargement du mapping Material et des noms de glyphes"
telecharger "$tmp/fileIcons.ts" "$MIT/src/core/icons/fileIcons.ts"
telecharger "$tmp/folderIcons.ts" "$MIT/src/core/icons/folderIcons.ts"
telecharger "$tmp/glyphnames.json" "$NF"

python3 -I "$ICI/parse_material.py" "$tmp" "$tmp/material_map.json"

echo "Téléchargement des icônes Material utilisées"
mapfile -t icones < <(python3 -I "$ICI/gen_theme.py" icones "$tmp/material_map.json")
for n in "${icones[@]}"; do
  if ! telecharger "$tmp/svg/$n.svg" "$MIT/icons/$n.svg" 2>/dev/null; then
    rm -f "$tmp/svg/$n.svg"
  fi
done

python3 -I "$ICI/gen_theme.py" theme "$tmp/material_map.json" "$tmp/svg" "$tmp/glyphnames.json" "$ICI/theme.yml"
echo "Écrit : $ICI/theme.yml"
