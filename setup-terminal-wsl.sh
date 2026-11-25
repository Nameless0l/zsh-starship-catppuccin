#!/usr/bin/env bash
# Config terminal pour WSL (Ubuntu sous Windows) : zsh, Starship, outils.
# Rien de graphique : pas d'extension GNOME, pas de police, pas de réglage Ptyxis.
# Usage : bash setup-terminal-wsl.sh (sans sudo, il le demande quand il en a besoin)
# Sans droits sudo, les paquets sont sautés et le reste s'installe dans ton dossier personnel.
# Relançable sans risque : chaque fichier remplacé est d'abord sauvegardé en .bak daté.

if [ "$(id -u)" -eq 0 ]; then
  echo "Lance ce script sans sudo."
  exit 1
fi

titre() { printf '\n== %s ==\n' "$1"; }

sauvegarde() {
  if [ -f "$1" ]; then
    cp "$1" "$1.bak-$(date +%Y%m%d-%H%M%S)"
  fi
}

# ---------- Paquets ----------
titre "Paquets apt"
SUDO_OK=0
if command -v apt-get >/dev/null 2>&1 && command -v sudo >/dev/null 2>&1; then
  if sudo -v; then
    SUDO_OK=1
  fi
fi

PAQUETS="git curl zsh zsh-autosuggestions zsh-syntax-highlighting fzf zoxide eza bat git-delta btop fastfetch ripgrep fd-find lazygit nvtop glow hyperfine"
if [ "$SUDO_OK" -eq 1 ]; then
  if command -v add-apt-repository >/dev/null 2>&1; then
    for depot in universe multiverse; do
      if ! sudo add-apt-repository -y "$depot"; then
        echo "[!!] dépôt $depot non ajouté, à vérifier à la main"
      fi
    done
  fi
  sudo apt-get update
  for p in $PAQUETS; do
    if dpkg -s "$p" >/dev/null 2>&1; then
      continue
    fi
    if ! sudo apt-get install -y "$p"; then
      echo "[!!] paquet indisponible : $p"
    fi
  done
else
  echo "[..] pas de sudo ou pas d'apt : paquets non installés, le reste continue"
fi

# ---------- Starship ----------
titre "Starship"
mkdir -p "$HOME/.local/bin"
if [ ! -x "$HOME/.local/bin/starship" ]; then
  if ! command -v starship >/dev/null 2>&1; then
    if curl -fsSL https://starship.rs/install.sh -o /tmp/starship-install.sh; then
      sh /tmp/starship-install.sh -y -b "$HOME/.local/bin"
    else
      echo "[!!] Starship non téléchargé"
    fi
  fi
fi

# ---------- Windows Terminal : police Nerd Font et couleurs Catppuccin Mocha ----------
titre "Windows Terminal"
WT_SETTINGS=""
if command -v cmd.exe >/dev/null 2>&1 && command -v wslpath >/dev/null 2>&1; then
  win_local="$(cd /mnt/c 2>/dev/null && cmd.exe /c 'echo %LOCALAPPDATA%' 2>/dev/null)"
  win_local="${win_local%$'\r'}"
  if [ -n "$win_local" ]; then
    for d in Microsoft.WindowsTerminal_8wekyb3d8bbwe Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe; do
      f="$(wslpath -u "$win_local")/Packages/$d/LocalState/settings.json"
      if [ -f "$f" ]; then
        WT_SETTINGS="$f"
        break
      fi
    done
  fi
fi
WT_MANUEL=1
if [ -n "$WT_SETTINGS" ]; then
  sauvegarde "$WT_SETTINGS"
  if python3 - "$WT_SETTINGS" << 'WT_EOF'
import json
import sys

chemin = sys.argv[1]
SCHEME = {"name": "Catppuccin Mocha", "cursorColor": "#F5E0DC", "selectionBackground": "#585B70", "background": "#1E1E2E", "foreground": "#CDD6F4", "black": "#45475A", "red": "#F38BA8", "green": "#A6E3A1", "yellow": "#F9E2AF", "blue": "#89B4FA", "purple": "#F5C2E7", "cyan": "#94E2D5", "white": "#BAC2DE", "brightBlack": "#585B70", "brightRed": "#F38BA8", "brightGreen": "#A6E3A1", "brightYellow": "#F9E2AF", "brightBlue": "#89B4FA", "brightPurple": "#F5C2E7", "brightCyan": "#94E2D5", "brightWhite": "#A6ADC8"}
POLICE = "JetBrainsMono Nerd Font"

try:
    with open(chemin, encoding="utf-8-sig") as f:
        d = json.load(f)
except ValueError:
    print("[!!] settings.json contient des commentaires, il n'est pas modifié")
    sys.exit(1)

schemes = [s for s in d.get("schemes", []) if s.get("name") != SCHEME["name"]]
schemes.append(SCHEME)
d["schemes"] = schemes

profiles = d.setdefault("profiles", {})
if isinstance(profiles, list):
    profiles = d["profiles"] = {"defaults": {}, "list": profiles}
defaults = profiles.setdefault("defaults", {})
defaults.setdefault("font", {})["face"] = POLICE

# Couleurs sur les profils WSL et Ubuntu, qui gardent sinon le jeu de couleurs de leur distribution
n = 0
for p in profiles.get("list", []):
    nom = str(p.get("name", "")).lower()
    source = str(p.get("source", "")).lower()
    if "ubuntu" in nom or "wsl" in source or "canonical" in source:
        p["colorScheme"] = SCHEME["name"]
        n += 1

with open(chemin, "w", encoding="utf-8") as f:
    json.dump(d, f, indent=4, ensure_ascii=False)
    f.write("\n")
print(f"[ok] Windows Terminal : police {POLICE}, couleurs Catppuccin Mocha sur {n} profil(s) Ubuntu/WSL")
WT_EOF
  then
    WT_MANUEL=0
  fi
fi

# ---------- Plugins zsh ----------
titre "Plugins zsh"
mkdir -p "$HOME/.zsh"
cloner() {
  if [ -d "$2" ]; then
    return
  fi
  if ! command -v git >/dev/null 2>&1; then
    echo "[!!] git absent, non cloné : $1"
    return
  fi
  if ! git clone --depth 1 "$1" "$2"; then
    echo "[!!] clone échoué : $1"
  fi
}
cloner https://github.com/Aloxaf/fzf-tab "$HOME/.zsh/fzf-tab"
# Sans les paquets apt, les deux plugins sont pris sur GitHub
if [ ! -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
  cloner https://github.com/zsh-users/zsh-autosuggestions "$HOME/.zsh/zsh-autosuggestions"
fi
if [ ! -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
  cloner https://github.com/zsh-users/zsh-syntax-highlighting "$HOME/.zsh/zsh-syntax-highlighting"
fi

# ---------- eza récent (le thème demande la version 0.20 ou plus) ----------
titre "eza"
eza_version() {
  local sortie
  sortie="$(eza --version 2>/dev/null)"
  if [[ $sortie =~ v([0-9]+)\.([0-9]+) ]]; then
    echo "${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"
  else
    echo "0.0"
  fi
}
v="$(eza_version)"
if [ "${v%%.*}" -eq 0 ] && [ "${v#*.}" -lt 20 ]; then
  if [ "${SUDO_OK:-1}" -eq 1 ] && command -v apt-get >/dev/null 2>&1; then
    # Dépôt officiel d'eza (deb.gierens.de), plus récent que celui d'Ubuntu
    sudo apt-get install -y gpg
    sudo mkdir -p /etc/apt/keyrings
    if curl -fsSL -o /tmp/eza-deb.asc https://raw.githubusercontent.com/eza-community/eza/main/deb.asc; then
      sudo gpg --dearmor --yes -o /etc/apt/keyrings/gierens.gpg /tmp/eza-deb.asc
      sudo sh -c 'echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" > /etc/apt/sources.list.d/gierens.list'
      sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
      sudo apt-get update
      sudo apt-get install -y eza
      echo "[ok] eza $(eza_version)"
    else
      echo "[!!] clé du dépôt eza non téléchargée, eza $v garde ses icônes par défaut"
    fi
  else
    echo "[..] eza $v trop ancien pour le thème (0.20 minimum), icônes par défaut"
  fi
fi

# ---------- Thème eza façon Material Icon Theme (VS Code) ----------
titre "Thème eza"
mkdir -p "$HOME/.config/eza"
sauvegarde "$HOME/.config/eza/theme.yml"
cat > "$HOME/.config/eza/theme.yml" << 'EZA_THEME_EOF'
# Thème eza façon Material Icon Theme (VS Code)
# Couleurs reprises des icônes Material, glyphes du jeu Material Design de Nerd Fonts.
# Généré automatiquement : relancer le générateur plutôt que d'éditer à la main.

filekinds:
  directory: {foreground: "#90a4ae", is_bold: true}

filenames:
  ".bashrc": {icon: {glyph: "󰆍", style: {foreground: "#ff7043"}}}
  ".cache": {icon: {glyph: "󰪺", style: {foreground: "#0097a7"}}}
  ".cargo": {icon: {glyph: "󱁿", style: {foreground: "#ff7043"}}}
  ".config": {icon: {glyph: "", style: {foreground: "#00acc1"}}}
  ".dockerignore": {icon: {glyph: "󰡨", style: {foreground: "#0288d1"}}}
  ".editorconfig": {icon: {glyph: "󰒓", style: {foreground: "#efebe9"}}}
  ".env": {icon: {glyph: "󰘮", style: {foreground: "#fbc02d"}}}
  ".env.example": {icon: {glyph: "󰘮", style: {foreground: "#fbc02d"}}}
  ".git": {icon: {glyph: "", style: {foreground: "#ff7043"}}}
  ".gitattributes": {icon: {glyph: "󰊢", style: {foreground: "#e64a19"}}}
  ".github": {icon: {glyph: "", style: {foreground: "#546e7a"}}}
  ".gitignore": {icon: {glyph: "󰊢", style: {foreground: "#e64a19"}}}
  ".gitmodules": {icon: {glyph: "󰊢", style: {foreground: "#e64a19"}}}
  ".idea": {icon: {glyph: "󱁿", style: {foreground: "#ec407a"}}}
  ".local": {icon: {glyph: "󱂵", style: {foreground: "#ff5252"}}}
  ".profile": {icon: {glyph: "󰆍", style: {foreground: "#ff7043"}}}
  ".shell_common": {icon: {glyph: "󰆍", style: {foreground: "#ff7043"}}}
  ".ssh": {icon: {glyph: "󰢬", style: {foreground: "#26a69a"}}}
  ".venv": {icon: {glyph: "󱁿", style: {foreground: "#66bb6a"}}}
  ".vscode": {icon: {glyph: "󱁿", style: {foreground: "#42a5f5"}}}
  ".zshrc": {icon: {glyph: "󰆍", style: {foreground: "#ff7043"}}}
  "android": {icon: {glyph: "󱁿", style: {foreground: "#8bc34a"}}}
  "AndroidManifest.xml": {icon: {glyph: "󰀲", style: {foreground: "#8bc34a"}}}
  "api": {icon: {glyph: "󰡰", style: {foreground: "#fbc02d"}}}
  "app": {icon: {glyph: "󰚝", style: {foreground: "#ef5350"}}}
  "artisan": {icon: {glyph: "󰫐", style: {foreground: "#ff5252"}}}
  "assets": {icon: {glyph: "󰚝", style: {foreground: "#fbc02d"}}}
  "bblayers.conf": {icon: {glyph: "󰆧", style: {foreground: "#ff9800"}}}
  "bin": {icon: {glyph: "󰛫", style: {foreground: "#e57373"}}}
  "build": {icon: {glyph: "󰛫", style: {foreground: "#e57373"}}}
  "build.gradle": {icon: {glyph: "", style: {foreground: "#0097a7"}}}
  "Bureau": {icon: {glyph: "󰉌", style: {foreground: "#039be5"}}}
  "Cargo.lock": {icon: {glyph: "󰌾", style: {foreground: "#ffd54f"}}}
  "Cargo.toml": {icon: {glyph: "", style: {foreground: "#ef5350"}}}
  "CHANGELOG.md": {icon: {glyph: "󰋚", style: {foreground: "#8bc34a"}}}
  "client": {icon: {glyph: "󰉌", style: {foreground: "#039be5"}}}
  "CMakeLists.txt": {icon: {glyph: "", style: {foreground: "#1e88e5"}}}
  "components": {icon: {glyph: "󰉓", style: {foreground: "#c0ca33"}}}
  "compose.yaml": {icon: {glyph: "󰡨", style: {foreground: "#0288d1"}}}
  "compose.yml": {icon: {glyph: "󰡨", style: {foreground: "#0288d1"}}}
  "composer.json": {icon: {glyph: "󰘦", style: {foreground: "#f9a825"}}}
  "composer.lock": {icon: {glyph: "󰘦", style: {foreground: "#f9a825"}}}
  "config": {icon: {glyph: "", style: {foreground: "#00acc1"}}}
  "configs": {icon: {glyph: "", style: {foreground: "#00acc1"}}}
  "data": {icon: {glyph: "󱋣", style: {foreground: "#ffca28"}}}
  "database": {icon: {glyph: "󱋣", style: {foreground: "#ffca28"}}}
  "Desktop": {icon: {glyph: "󰉌", style: {foreground: "#039be5"}}}
  "dist": {icon: {glyph: "󰛫", style: {foreground: "#e57373"}}}
  "doc": {icon: {glyph: "󰲂", style: {foreground: "#0277bd"}}}
  "docker": {icon: {glyph: "󱁿", style: {foreground: "#039be5"}}}
  "docker-compose.yaml": {icon: {glyph: "󰡨", style: {foreground: "#0288d1"}}}
  "docker-compose.yml": {icon: {glyph: "󰡨", style: {foreground: "#0288d1"}}}
  "Dockerfile": {icon: {glyph: "󰡨", style: {foreground: "#0288d1"}}}
  "dockerfile": {icon: {glyph: "󰡨", style: {foreground: "#0288d1"}}}
  "docs": {icon: {glyph: "󰲂", style: {foreground: "#0277bd"}}}
  "Documents": {icon: {glyph: "󰲂", style: {foreground: "#0277bd"}}}
  "downloads": {icon: {glyph: "󰉍", style: {foreground: "#4caf50"}}}
  "Downloads": {icon: {glyph: "󰉍", style: {foreground: "#4caf50"}}}
  "env": {icon: {glyph: "󱁿", style: {foreground: "#66bb6a"}}}
  "examples": {icon: {glyph: "󰥨", style: {foreground: "#009688"}}}
  "fonts": {icon: {glyph: "󰲂", style: {foreground: "#ff5252"}}}
  "GNUmakefile": {icon: {glyph: "󱌣", style: {foreground: "#ef5350"}}}
  "go.mod": {icon: {glyph: "󰟓", style: {foreground: "#ec407a"}}}
  "go.sum": {icon: {glyph: "󰟓", style: {foreground: "#ec407a"}}}
  "gradlew": {icon: {glyph: "", style: {foreground: "#0097a7"}}}
  "hooks": {icon: {glyph: "󰴋", style: {foreground: "#7e57c2"}}}
  "images": {icon: {glyph: "󰉏", style: {foreground: "#009688"}}}
  "Images": {icon: {glyph: "󰉏", style: {foreground: "#009688"}}}
  "img": {icon: {glyph: "󰉏", style: {foreground: "#009688"}}}
  "include": {icon: {glyph: "󱂷", style: {foreground: "#039be5"}}}
  "keys": {icon: {glyph: "󰢬", style: {foreground: "#26a69a"}}}
  "lib": {icon: {glyph: "󰉓", style: {foreground: "#c0ca33"}}}
  "LICENSE": {icon: {glyph: "󰿃", style: {foreground: "#ff5722"}}}
  "license": {icon: {glyph: "󰿃", style: {foreground: "#ff5722"}}}
  "LICENSE.md": {icon: {glyph: "󰿃", style: {foreground: "#ff5722"}}}
  "LICENSE.txt": {icon: {glyph: "󰿃", style: {foreground: "#ff5722"}}}
  "local.conf": {icon: {glyph: "󰆧", style: {foreground: "#ff9800"}}}
  "logs": {icon: {glyph: "󰷌", style: {foreground: "#afb42b"}}}
  "Makefile": {icon: {glyph: "󱌣", style: {foreground: "#ef5350"}}}
  "makefile": {icon: {glyph: "󱌣", style: {foreground: "#ef5350"}}}
  "meta": {icon: {glyph: "󱂷", style: {foreground: "#7cb342"}}}
  "migrations": {icon: {glyph: "󰴋", style: {foreground: "#ec407a"}}}
  "models": {icon: {glyph: "󰚝", style: {foreground: "#ef5350"}}}
  "Modèles": {icon: {glyph: "󱧶", style: {foreground: "#8d6e63"}}}
  "Music": {icon: {glyph: "󱍙", style: {foreground: "#ef5350"}}}
  "Musique": {icon: {glyph: "󱍙", style: {foreground: "#ef5350"}}}
  "node_modules": {icon: {glyph: "", style: {foreground: "#8bc34a"}}}
  "notebooks": {icon: {glyph: "󰲂", style: {foreground: "#ff9800"}}}
  "out": {icon: {glyph: "󰛫", style: {foreground: "#e57373"}}}
  "package-lock.json": {icon: {glyph: "󰎙", style: {foreground: "#8bc34a"}}}
  "package.json": {icon: {glyph: "󰎙", style: {foreground: "#8bc34a"}}}
  "patches": {icon: {glyph: "", style: {foreground: "#ff7043"}}}
  "Pictures": {icon: {glyph: "󰉏", style: {foreground: "#009688"}}}
  "plugins": {icon: {glyph: "󱁿", style: {foreground: "#0288d1"}}}
  "public": {icon: {glyph: "󰉙", style: {foreground: "#039be5"}}}
  "Public": {icon: {glyph: "󰉙", style: {foreground: "#039be5"}}}
  "pyproject.toml": {icon: {glyph: "󰌠", style: {foreground: "#0288d1"}}}
  "README": {icon: {glyph: "󰋼", style: {foreground: "#42a5f5"}}}
  "README.md": {icon: {glyph: "󰋼", style: {foreground: "#42a5f5"}}}
  "readme.md": {icon: {glyph: "󰋼", style: {foreground: "#42a5f5"}}}
  "README.txt": {icon: {glyph: "󰋼", style: {foreground: "#42a5f5"}}}
  "requirements.txt": {icon: {glyph: "󰌠", style: {foreground: "#0288d1"}}}
  "resources": {icon: {glyph: "󰚝", style: {foreground: "#fbc02d"}}}
  "routes": {icon: {glyph: "󰡰", style: {foreground: "#43a047"}}}
  "scripts": {icon: {glyph: "󱧺", style: {foreground: "#546e7a"}}}
  "secrets": {icon: {glyph: "󰢬", style: {foreground: "#26a69a"}}}
  "server": {icon: {glyph: "󰡰", style: {foreground: "#fbc02d"}}}
  "settings.gradle": {icon: {glyph: "", style: {foreground: "#0097a7"}}}
  "setup.py": {icon: {glyph: "󰌠", style: {foreground: "#0288d1"}}}
  "source": {icon: {glyph: "󰴉", style: {foreground: "#4caf50"}}}
  "spec": {icon: {glyph: "󱥾", style: {foreground: "#00bfa5"}}}
  "src": {icon: {glyph: "󰴉", style: {foreground: "#4caf50"}}}
  "storage": {icon: {glyph: "󱋣", style: {foreground: "#ffca28"}}}
  "target": {icon: {glyph: "󱉭", style: {foreground: "#546e7a"}}}
  "temp": {icon: {glyph: "󰪺", style: {foreground: "#0097a7"}}}
  "Templates": {icon: {glyph: "󱧶", style: {foreground: "#8d6e63"}}}
  "test": {icon: {glyph: "󱥾", style: {foreground: "#00bfa5"}}}
  "tests": {icon: {glyph: "󱥾", style: {foreground: "#00bfa5"}}}
  "themes": {icon: {glyph: "󰚝", style: {foreground: "#1e88e5"}}}
  "tmp": {icon: {glyph: "󰪺", style: {foreground: "#0097a7"}}}
  "tools": {icon: {glyph: "󱧼", style: {foreground: "#1e88e5"}}}
  "tsconfig.json": {icon: {glyph: "󰛦", style: {foreground: "#0288d1"}}}
  "Téléchargements": {icon: {glyph: "󰉍", style: {foreground: "#4caf50"}}}
  "utils": {icon: {glyph: "󱧼", style: {foreground: "#7cb342"}}}
  "vendor": {icon: {glyph: "󰉓", style: {foreground: "#c0ca33"}}}
  "venv": {icon: {glyph: "󱁿", style: {foreground: "#66bb6a"}}}
  "Videos": {icon: {glyph: "󱧺", style: {foreground: "#ff9800"}}}
  "Vidéos": {icon: {glyph: "󱧺", style: {foreground: "#ff9800"}}}
  "views": {icon: {glyph: "󱞊", style: {foreground: "#ff7043"}}}

extensions:
  "7z": {icon: {glyph: "󰗄", style: {foreground: "#afb42b"}}}
  "a": {icon: {glyph: "󰌱", style: {foreground: "#8bc34a"}}}
  "aab": {icon: {glyph: "󰀲", style: {foreground: "#8bc34a"}}}
  "apk": {icon: {glyph: "󰀲", style: {foreground: "#8bc34a"}}}
  "asm": {icon: {glyph: "󰘚", style: {foreground: "#ff6e40"}}}
  "avi": {icon: {glyph: "󰈫", style: {foreground: "#ff9800"}}}
  "bash": {icon: {glyph: "󰆍", style: {foreground: "#ff7043"}}}
  "bat": {icon: {glyph: "󰆍", style: {foreground: "#ff7043"}}}
  "bb": {icon: {glyph: "󰆧", style: {foreground: "#ff9800"}}}
  "bbappend": {icon: {glyph: "󰆧", style: {foreground: "#ffb74d"}}}
  "bbclass": {icon: {glyph: "󰆧", style: {foreground: "#ff9800"}}}
  "bib": {icon: {glyph: "󰗚", style: {foreground: "#2196f3"}}}
  "bin": {icon: {glyph: "󱊧", style: {foreground: "#26a69a"}}}
  "bmp": {icon: {glyph: "󰈟", style: {foreground: "#26a69a"}}}
  "bz2": {icon: {glyph: "󰗄", style: {foreground: "#afb42b"}}}
  "c": {icon: {glyph: "󰙱", style: {foreground: "#0288d1"}}}
  "cc": {icon: {glyph: "󰙲", style: {foreground: "#0288d1"}}}
  "cfg": {icon: {glyph: "󰒓", style: {foreground: "#42a5f5"}}}
  "cjs": {icon: {glyph: "󰌞", style: {foreground: "#ffca28"}}}
  "cls": {icon: {glyph: "", style: {foreground: "#2196f3"}}}
  "cmake": {icon: {glyph: "", style: {foreground: "#1e88e5"}}}
  "cmd": {icon: {glyph: "󰆍", style: {foreground: "#ff7043"}}}
  "conf": {icon: {glyph: "󰒓", style: {foreground: "#42a5f5"}}}
  "cpp": {icon: {glyph: "󰙲", style: {foreground: "#0288d1"}}}
  "crt": {icon: {glyph: "󰄤", style: {foreground: "#ff5722"}}}
  "cs": {icon: {glyph: "󰌛", style: {foreground: "#0288d1"}}}
  "css": {icon: {glyph: "󰌜", style: {foreground: "#7e57c2"}}}
  "csv": {icon: {glyph: "󰱾", style: {foreground: "#8bc34a"}}}
  "cxx": {icon: {glyph: "󰙲", style: {foreground: "#0288d1"}}}
  "db": {icon: {glyph: "󰆼", style: {foreground: "#ffca28"}}}
  "deb": {icon: {glyph: "󰗄", style: {foreground: "#afb42b"}}}
  "dex": {icon: {glyph: "󰀲", style: {foreground: "#8bc34a"}}}
  "diff": {icon: {glyph: "󰢪", style: {foreground: "#42a5f5"}}}
  "dll": {icon: {glyph: "󰙵", style: {foreground: "#42a5f5"}}}
  "doc": {icon: {glyph: "󰈭", style: {foreground: "#01579b"}}}
  "docx": {icon: {glyph: "󰈭", style: {foreground: "#01579b"}}}
  "dts": {icon: {glyph: "󰘚", style: {foreground: "#26a69a"}}}
  "dtsi": {icon: {glyph: "󰘚", style: {foreground: "#26a69a"}}}
  "elf": {icon: {glyph: "󰘚", style: {foreground: "#8bc34a"}}}
  "env": {icon: {glyph: "󰘮", style: {foreground: "#fbc02d"}}}
  "exe": {icon: {glyph: "󰣆", style: {foreground: "#e64a19"}}}
  "fish": {icon: {glyph: "󰆍", style: {foreground: "#ff7043"}}}
  "flac": {icon: {glyph: "󰝚", style: {foreground: "#ef5350"}}}
  "gif": {icon: {glyph: "󰈟", style: {foreground: "#26a69a"}}}
  "go": {icon: {glyph: "󰟓", style: {foreground: "#00acc1"}}}
  "gradle": {icon: {glyph: "", style: {foreground: "#0097a7"}}}
  "graphql": {icon: {glyph: "󰡷", style: {foreground: "#ec407a"}}}
  "gz": {icon: {glyph: "󰗄", style: {foreground: "#afb42b"}}}
  "h": {icon: {glyph: "󰙱", style: {foreground: "#0288d1"}}}
  "hex": {icon: {glyph: "󱊧", style: {foreground: "#26a69a"}}}
  "hh": {icon: {glyph: "󰙲", style: {foreground: "#0288d1"}}}
  "hpp": {icon: {glyph: "󰙲", style: {foreground: "#0288d1"}}}
  "htm": {icon: {glyph: "󰌝", style: {foreground: "#e65100"}}}
  "html": {icon: {glyph: "󰌝", style: {foreground: "#e65100"}}}
  "http": {icon: {glyph: "󰖟", style: {foreground: "#e53935"}}}
  "ico": {icon: {glyph: "󰈟", style: {foreground: "#26a69a"}}}
  "img": {icon: {glyph: "󰈟", style: {foreground: "#26a69a"}}}
  "ini": {icon: {glyph: "󰒓", style: {foreground: "#42a5f5"}}}
  "ipynb": {icon: {glyph: "󰠮", style: {foreground: "#f57c00"}}}
  "iso": {icon: {glyph: "󰗮", style: {foreground: "#b0bec5"}}}
  "jar": {icon: {glyph: "󰬷", style: {foreground: "#f44336"}}}
  "java": {icon: {glyph: "󰬷", style: {foreground: "#f44336"}}}
  "jpeg": {icon: {glyph: "󰈟", style: {foreground: "#26a69a"}}}
  "jpg": {icon: {glyph: "󰈟", style: {foreground: "#26a69a"}}}
  "js": {icon: {glyph: "󰌞", style: {foreground: "#ffca28"}}}
  "json": {icon: {glyph: "󰘦", style: {foreground: "#f9a825"}}}
  "jsonc": {icon: {glyph: "󰘦", style: {foreground: "#f9a825"}}}
  "jsx": {icon: {glyph: "󰜈", style: {foreground: "#00bcd4"}}}
  "key": {icon: {glyph: "󰌆", style: {foreground: "#26a69a"}}}
  "kt": {icon: {glyph: "󱈙", style: {foreground: "#d500f9"}}}
  "kts": {icon: {glyph: "󱈙", style: {foreground: "#d500f9"}}}
  "ld": {icon: {glyph: "󰍛", style: {foreground: "#90a4ae"}}}
  "lock": {icon: {glyph: "󰌾", style: {foreground: "#ffd54f"}}}
  "log": {icon: {glyph: "󰉹", style: {foreground: "#afb42b"}}}
  "lua": {icon: {glyph: "󰢱", style: {foreground: "#42a5f5"}}}
  "markdown": {icon: {glyph: "󰍔", style: {foreground: "#42a5f5"}}}
  "md": {icon: {glyph: "󰍔", style: {foreground: "#42a5f5"}}}
  "mjs": {icon: {glyph: "󰌞", style: {foreground: "#ffca28"}}}
  "mk": {icon: {glyph: "󱌣", style: {foreground: "#ef5350"}}}
  "mkv": {icon: {glyph: "󰈫", style: {foreground: "#ff9800"}}}
  "mov": {icon: {glyph: "󰈫", style: {foreground: "#ff9800"}}}
  "mp3": {icon: {glyph: "󰝚", style: {foreground: "#ef5350"}}}
  "mp4": {icon: {glyph: "󰈫", style: {foreground: "#ff9800"}}}
  "nix": {icon: {glyph: "󱄅", style: {foreground: "#1976d2"}}}
  "o": {icon: {glyph: "󰆧", style: {foreground: "#90a4ae"}}}
  "odt": {icon: {glyph: "󰈭", style: {foreground: "#01579b"}}}
  "ogg": {icon: {glyph: "󰈫", style: {foreground: "#ff9800"}}}
  "otf": {icon: {glyph: "󰛖", style: {foreground: "#f44336"}}}
  "patch": {icon: {glyph: "󰊢", style: {foreground: "#e64a19"}}}
  "pdf": {icon: {glyph: "󰈦", style: {foreground: "#ef5350"}}}
  "pem": {icon: {glyph: "󰌆", style: {foreground: "#26a69a"}}}
  "php": {icon: {glyph: "󰌟", style: {foreground: "#1e88e5"}}}
  "png": {icon: {glyph: "󰈟", style: {foreground: "#26a69a"}}}
  "ppt": {icon: {glyph: "󰈨", style: {foreground: "#e64a19"}}}
  "pptx": {icon: {glyph: "󰈨", style: {foreground: "#e64a19"}}}
  "proto": {icon: {glyph: "󰿘", style: {foreground: "#03a9f4"}}}
  "ps1": {icon: {glyph: "󰨊", style: {foreground: "#03a9f4"}}}
  "pub": {icon: {glyph: "󰌆", style: {foreground: "#26a69a"}}}
  "py": {icon: {glyph: "󰌠", style: {foreground: "#0288d1"}}}
  "pyi": {icon: {glyph: "󰌠", style: {foreground: "#0288d1"}}}
  "r": {icon: {glyph: "󰟔", style: {foreground: "#1976d2"}}}
  "rar": {icon: {glyph: "󰗄", style: {foreground: "#afb42b"}}}
  "rb": {icon: {glyph: "󰴭", style: {foreground: "#f44336"}}}
  "rpm": {icon: {glyph: "󰗄", style: {foreground: "#afb42b"}}}
  "rs": {icon: {glyph: "󱘗", style: {foreground: "#ff7043"}}}
  "rst": {icon: {glyph: "󰍔", style: {foreground: "#42a5f5"}}}
  "s": {icon: {glyph: "󰘚", style: {foreground: "#ff6e40"}}}
  "sass": {icon: {glyph: "󰟬", style: {foreground: "#ec407a"}}}
  "scss": {icon: {glyph: "󰟬", style: {foreground: "#ec407a"}}}
  "service": {icon: {glyph: "󰒓", style: {foreground: "#42a5f5"}}}
  "sh": {icon: {glyph: "󰆍", style: {foreground: "#ff7043"}}}
  "smali": {icon: {glyph: "󰀲", style: {foreground: "#8bc34a"}}}
  "so": {icon: {glyph: "󰙵", style: {foreground: "#42a5f5"}}}
  "sql": {icon: {glyph: "󰆼", style: {foreground: "#ffca28"}}}
  "sqlite": {icon: {glyph: "󰆼", style: {foreground: "#ffca28"}}}
  "sty": {icon: {glyph: "", style: {foreground: "#2196f3"}}}
  "svelte": {icon: {glyph: "", style: {foreground: "#ff5722"}}}
  "svg": {icon: {glyph: "󰜡", style: {foreground: "#ffb300"}}}
  "swift": {icon: {glyph: "󰛥", style: {foreground: "#ff6e40"}}}
  "tar": {icon: {glyph: "󰗄", style: {foreground: "#afb42b"}}}
  "tex": {icon: {glyph: "", style: {foreground: "#2196f3"}}}
  "tgz": {icon: {glyph: "󰗄", style: {foreground: "#afb42b"}}}
  "toml": {icon: {glyph: "", style: {foreground: "#ef5350"}}}
  "ts": {icon: {glyph: "󰛦", style: {foreground: "#0288d1"}}}
  "tsv": {icon: {glyph: "󰱾", style: {foreground: "#8bc34a"}}}
  "tsx": {icon: {glyph: "󰜈", style: {foreground: "#0288d1"}}}
  "ttf": {icon: {glyph: "󰛖", style: {foreground: "#f44336"}}}
  "txt": {icon: {glyph: "󰈙", style: {foreground: "#42a5f5"}}}
  "vue": {icon: {glyph: "󰡄", style: {foreground: "#41b883"}}}
  "wav": {icon: {glyph: "󰝚", style: {foreground: "#ef5350"}}}
  "webm": {icon: {glyph: "󰈫", style: {foreground: "#ff9800"}}}
  "webp": {icon: {glyph: "󰈟", style: {foreground: "#26a69a"}}}
  "woff": {icon: {glyph: "󰛖", style: {foreground: "#f44336"}}}
  "woff2": {icon: {glyph: "󰛖", style: {foreground: "#f44336"}}}
  "xls": {icon: {glyph: "󰱾", style: {foreground: "#8bc34a"}}}
  "xlsx": {icon: {glyph: "󰱾", style: {foreground: "#8bc34a"}}}
  "xml": {icon: {glyph: "󰗀", style: {foreground: "#8bc34a"}}}
  "xz": {icon: {glyph: "󰗄", style: {foreground: "#afb42b"}}}
  "yaml": {icon: {glyph: "", style: {foreground: "#ff5252"}}}
  "yml": {icon: {glyph: "", style: {foreground: "#ff5252"}}}
  "zip": {icon: {glyph: "󰗄", style: {foreground: "#afb42b"}}}
  "zsh": {icon: {glyph: "󰆍", style: {foreground: "#ff7043"}}}
  "zst": {icon: {glyph: "󰗄", style: {foreground: "#afb42b"}}}
EZA_THEME_EOF

# ---------- ~/.zshrc ----------
titre "~/.zshrc"
sauvegarde "$HOME/.zshrc"
cat > "$HOME/.zshrc" << 'ZSHRC_EOF'
# ==================== PATH ====================
# En premier, pour que starship et les autres outils soient trouvés
typeset -U path PATH                      # pas de doublons dans le PATH
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"

# ==================== Historique ====================
HISTFILE=~/.zsh_history
HISTSIZE=100000
SAVEHIST=100000
setopt share_history                      # partagé entre tous les terminaux
setopt extended_history                   # garde la date de chaque commande
setopt hist_ignore_all_dups               # supprime aussi les doublons non consécutifs
setopt hist_ignore_space                  # " commande" n'est pas enregistrée
setopt hist_reduce_blanks
setopt hist_verify                        # !! et !$ s'affichent avant d'être exécutés

# ==================== Options du shell ====================
setopt interactive_comments               # pour les tags "# montag"
setopt auto_cd                            # taper un dossier (ou ..) suffit pour y aller
setopt auto_pushd pushd_ignore_dups       # cd -<Tab> pour revenir en arrière
unsetopt flow_control                     # libère Ctrl+S

# ==================== Complétion ====================
fpath=(~/.zfunc $fpath)
autoload -Uz compinit
compinit

eval "$(dircolors -b)"
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'   # insensible à la casse
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}       # mêmes couleurs que ls
zstyle ':completion:*' group-name ''                        # résultats groupés par type

# ==================== Clavier ====================
bindkey -e                                # mode emacs, même si EDITOR=vim
bindkey '^[[1;5C' forward-word            # Ctrl+→
bindkey '^[[1;5D' backward-word           # Ctrl+←
bindkey '^H' backward-kill-word           # Ctrl+Retour arrière : efface le mot précédent
bindkey '^[[3;5~' kill-word               # Ctrl+Suppr : efface le mot suivant
bindkey '^[[3~' delete-char               # Suppr
bindkey '^[[H' beginning-of-line          # Début
bindkey '^[OH' beginning-of-line
bindkey '^[[F' end-of-line                # Fin
bindkey '^[OF' end-of-line

# ↑ et ↓ ne parcourent que les commandes qui commencent comme la ligne tapée
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[OA' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
bindkey '^[OB' down-line-or-beginning-search

# Ctrl+X puis Ctrl+E : éditer la commande dans ton éditeur
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line

# ==================== Alias et fonctions ====================
[ -f ~/.shell_common ] && . ~/.shell_common   # config partagée avec bash

# Placés après .shell_common pour ne pas être écrasés
if command -v eza >/dev/null; then
  # LS_COLORS vidé pour eza, sinon il passe devant ~/.config/eza/theme.yml
  eza() { LS_COLORS= command eza "$@"; }
  alias ls='eza --icons --group-directories-first'
  alias ll='eza -l --icons --git --group-directories-first'
  alias la='eza -la --icons --git --group-directories-first'
  alias lt='eza --tree --level=2 --icons --git-ignore'
else
  alias ls='ls --color=auto'
fi
command -v batcat  >/dev/null && alias cat='batcat --paging=never'
command -v fdfind  >/dev/null && alias fd='fdfind'
command -v lazygit >/dev/null && alias lg='lazygit'
alias cls='clear'

# ==================== Outils ====================
export BAT_THEME="ansi"                   # bat reprend les couleurs du terminal

# Pages man en couleur : titres et options en rouge, arguments en bleu
export MANPAGER="less -R --use-color -Dd+r -Du+b"
export MANROFFOPT="-P -c"

# fzf : Ctrl+R historique, Ctrl+T fichier avec aperçu, Alt+C dossier avec arbre
_fzf_colors="bg+:#313244,spinner:#f5e0dc,hl:#f38ba8,fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc,marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"
export FZF_DEFAULT_OPTS="--border=rounded --color=$_fzf_colors"
export FZF_CTRL_T_OPTS="--preview 'batcat --color=always --style=numbers --line-range=:200 {}'"
export FZF_ALT_C_OPTS="--preview 'LS_COLORS= eza --tree --level=2 --icons --color=always {}'"
if command -v fdfind >/dev/null; then
  # fd respecte le .gitignore : target/, build/ et .git restent hors des résultats
  export FZF_DEFAULT_COMMAND='fdfind --type f --hidden --follow --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fdfind --type d --hidden --follow --exclude .git'
fi
if command -v fzf >/dev/null; then
  if fzf --zsh >/dev/null 2>&1; then
    source <(fzf --zsh)                                    # fzf récent
  elif [ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]; then
    source /usr/share/doc/fzf/examples/key-bindings.zsh    # fzf ancien
  fi
fi

# fzf-tab : Tab ouvre fzf, avec aperçu du contenu des dossiers
# (chargé après fzf pour être le dernier à prendre la touche Tab)
if [ -f ~/.zsh/fzf-tab/fzf-tab.plugin.zsh ]; then
  source ~/.zsh/fzf-tab/fzf-tab.plugin.zsh
  zstyle ':completion:*' menu no
  zstyle ':completion:*:descriptions' format '[%d]'
  zstyle ':fzf-tab:*' fzf-flags --color=$_fzf_colors
  zstyle ':fzf-tab:*' switch-group '<' '>'
  zstyle ':fzf-tab:complete:cd:*' fzf-preview 'LS_COLORS= eza -1 --icons --color=always $realpath'
else
  zstyle ':completion:*' menu select                        # Tab ouvre un menu navigable
  zstyle ':completion:*:descriptions' format '%F{yellow}%d%f'
fi

# zoxide remplace cd : "cd morceau" saute dans un dossier déjà visité, "cdi" pour choisir avec fzf
command -v zoxide >/dev/null && eval "$(zoxide init zsh --cmd cd)"

# Suggestions grisées tirées de l'historique et de la complétion (→ pour accepter)
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#6c7086'
for _f in /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh; do
  if [ -f $_f ]; then
    source $_f
    break
  fi
done

# ==================== Prompt ====================
command -v starship >/dev/null && eval "$(starship init zsh)"

# Prompt transitoire : une fois la commande validée, il ne reste que ❯
autoload -Uz add-zle-hook-widget
_transient_prompt() {
  PROMPT='%F{green}❯%f ' RPROMPT='' zle .reset-prompt
  zle -R
}
add-zle-hook-widget zle-line-finish _transient_prompt

# ==================== Réglages propres à la machine ====================
# Alias, fonctions et variables perso : ~/.zshrc.local, jamais écrasé par le script
[ -f ~/.zshrc.local ] && source ~/.zshrc.local

# ==================== Toujours en dernier ====================
for _f in /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh; do
  if [ -f $_f ]; then
    source $_f
    break
  fi
done
unset _f
ZSHRC_EOF

# ---------- Starship (prompt deux lignes, Catppuccin Mocha) ----------
titre "starship.toml"
mkdir -p "$HOME/.config"
sauvegarde "$HOME/.config/starship.toml"
cat > "$HOME/.config/starship.toml" << 'STARSHIP_EOF'
"$schema" = 'https://starship.rs/config-schema.json'

add_newline = true

format = """
[╭─](fg:surface2)\
$os\
$username\
$hostname\
$directory\
$git_branch\
$git_status\
$git_metrics\
$c\
$python\
$nodejs\
$php\
$rust\
${custom.yocto}\
$fill\
$cmd_duration\
$status\
$jobs\
$sudo\
$time
[╰─](fg:surface2)$character"""

palette = 'catppuccin_mocha'

[os]
disabled = false
style = "bg:mauve fg:crust"
format = "[](fg:mauve)[ $symbol ]($style)"

[os.symbols]
Ubuntu = ""

[username]
show_always = true
style_user = "bg:mauve fg:crust"
style_root = "bg:mauve fg:red bold"
format = "[$user ]($style)[](fg:mauve) "

[hostname]
format = "[@$hostname](bold fg:mauve) "

[directory]
style = "bg:peach fg:crust"
read_only = " "
read_only_style = "bg:peach fg:red"
truncation_length = 3
truncation_symbol = "…/"
format = "[](fg:peach)[  $path]($style)[$read_only]($read_only_style)[ ]($style)[](fg:peach) "

[git_branch]
symbol = ""
style = "bg:yellow fg:crust"
format = "[](fg:yellow)[ $symbol $branch]($style)"

[git_status]
style = "bg:yellow fg:crust"
format = "[( $all_status$ahead_behind) ]($style)[](fg:yellow) "
ahead = "⇡${count}"
behind = "⇣${count}"
diverged = "⇕⇡${ahead_count}⇣${behind_count}"
modified = "!${count}"
staged = "+${count}"
untracked = "?${count}"
deleted = "✘${count}"
stashed = "≡${count}"

[git_metrics]
disabled = false
added_style = "fg:green"
deleted_style = "fg:red"
format = "([+$added]($added_style) )([-$deleted]($deleted_style) )"

[c]
symbol = ""
style = "bg:green fg:crust"
version_format = "${major}.${minor}"
format = "[](fg:green)[ $symbol( $version) ]($style)[](fg:green) "

[python]
symbol = ""
style = "bg:green fg:crust"
version_format = "${major}.${minor}"
format = "[](fg:green)[ $symbol( $version)( $virtualenv) ]($style)[](fg:green) "

[nodejs]
symbol = ""
style = "bg:green fg:crust"
version_format = "${major}.${minor}"
format = "[](fg:green)[ $symbol( $version) ]($style)[](fg:green) "

[php]
symbol = ""
style = "bg:green fg:crust"
version_format = "${major}.${minor}"
format = "[](fg:green)[ $symbol( $version) ]($style)[](fg:green) "

[rust]
symbol = ""
style = "bg:green fg:crust"
version_format = "${major}.${minor}"
format = "[](fg:green)[ $symbol( $version) ]($style)[](fg:green) "

[custom.yocto]
when = 'test -n "$BUILDDIR"'
command = 'basename "$BUILDDIR"'
shell = ["sh"]
symbol = ""
style = "bg:blue fg:crust"
format = "[](fg:blue)[ $symbol $output ]($style)[](fg:blue) "

[fill]
symbol = "─"
style = "fg:surface1"

[cmd_duration]
min_time = 2000
format = " [ $duration](fg:yellow)"

[status]
disabled = false
symbol = ""
style = "fg:red"
format = " [$symbol $status( $signal_name)]($style)"

[jobs]
symbol = " "
style = "fg:blue"
format = " [$symbol$number]($style)"

[sudo]
disabled = false
symbol = ""
style = "fg:peach"
format = " [$symbol]($style)"

[time]
disabled = false
time_format = "%R"
format = " [ $time](fg:lavender)"

[character]
success_symbol = "[❯](bold fg:green)"
error_symbol = "[❯](bold fg:red)"

[palettes.catppuccin_mocha]
red = "#f38ba8"
peach = "#fab387"
yellow = "#f9e2af"
green = "#a6e3a1"
blue = "#89b4fa"
mauve = "#cba6f7"
lavender = "#b4befe"
overlay1 = "#7f849c"
surface2 = "#585b70"
surface1 = "#45475a"
crust = "#11111b"
STARSHIP_EOF

# ---------- lazygit, btop, delta ----------
titre "lazygit, btop, delta"
mkdir -p "$HOME/.config/lazygit"
sauvegarde "$HOME/.config/lazygit/config.yml"
cat > "$HOME/.config/lazygit/config.yml" << 'LAZYGIT_EOF'
gui:
  nerdFontsVersion: "3"
  theme:
    activeBorderColor:
      - '#89b4fa'
      - bold
    inactiveBorderColor:
      - '#a6adc8'
    searchingActiveBorderColor:
      - '#f9e2af'
    optionsTextColor:
      - '#89b4fa'
    selectedLineBgColor:
      - '#313244'
    cherryPickedCommitBgColor:
      - '#45475a'
    cherryPickedCommitFgColor:
      - '#89b4fa'
    unstagedChangesColor:
      - '#f38ba8'
    defaultFgColor:
      - '#cdd6f4'
  authorColors:
    '*': '#b4befe'
LAZYGIT_EOF

# Thème btop Catppuccin Mocha : téléchargé puis activé dans btop.conf
BTOP_THEME="$HOME/.config/btop/themes/catppuccin_mocha.theme"
BTOP_CONF="$HOME/.config/btop/btop.conf"
mkdir -p "$HOME/.config/btop/themes"
if [ ! -f "$BTOP_THEME" ]; then
  if ! curl -fsSL -o "$BTOP_THEME" https://raw.githubusercontent.com/catppuccin/btop/main/themes/catppuccin_mocha.theme; then
    echo "[!!] thème btop non téléchargé"
    rm -f "$BTOP_THEME"
  fi
fi
if [ -f "$BTOP_THEME" ]; then
  if [ -f "$BTOP_CONF" ] && grep -q '^color_theme' "$BTOP_CONF"; then
    sed -i "s#^color_theme.*#color_theme = \"$BTOP_THEME\"#" "$BTOP_CONF"
  else
    echo "color_theme = \"$BTOP_THEME\"" >> "$BTOP_CONF"
  fi
  echo "[ok] btop : thème catppuccin_mocha"
fi

if command -v delta >/dev/null 2>&1; then
  git config --global core.pager delta
  git config --global interactive.diffFilter 'delta --color-only'
  git config --global delta.navigate true
  git config --global delta.line-numbers true
  git config --global merge.conflictStyle zdiff3
else
  echo "[..] delta absent, config git inchangée"
fi

# ---------- Shell par défaut ----------
titre "Shell par défaut"
if [ "$(basename "$SHELL")" != "zsh" ]; then
  if command -v zsh >/dev/null 2>&1; then
    chsh -s "$(command -v zsh)"
  else
    echo "[!!] zsh absent, shell par défaut inchangé"
  fi
fi

titre "Terminé"
echo "Ferme cette fenêtre WSL et rouvre-la pour arriver dans zsh."
echo "Les icônes du prompt viennent de la police de Windows, pas de WSL. Si elle manque, dans PowerShell :"
echo "  winget install -e --id DEVCOM.JetBrainsMonoNerdFont"
if [ "$WT_MANUEL" -eq 1 ]; then
  echo "Puis dans Windows Terminal : Paramètres, profil Ubuntu, Apparence, police JetBrainsMono Nerd Font et jeu de couleurs Catppuccin Mocha."
fi
if [ ! -f "$HOME/.zshrc.local" ]; then
  echo "Tes alias et fonctions perso vont dans ~/.zshrc.local : le script ne le touche jamais."
fi
