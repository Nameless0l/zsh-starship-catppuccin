#!/usr/bin/env bash
# Config terminal pour une machine sans écran, atteinte en SSH : zsh, Starship, outils.
# Rien de graphique : pas d'extension GNOME, pas de police, pas de réglage Ptyxis.
# Usage : bash setup-terminal-ssh.sh (sans sudo, il le demande quand il en a besoin ; en root, il s'en passe)
# Sans droits sudo, les paquets sont sautés et le reste s'installe dans le dossier personnel.
# Relançable sans risque : chaque fichier remplacé est d'abord sauvegardé en .bak daté.

# En root (carte embarquée, conteneur, serveur minimal), sudo n'est pas nécessaire
if [ "$(id -u)" -eq 0 ]; then
  SUDO=""
else
  SUDO="sudo"
fi

titre() { printf '\n== %s ==\n' "$1"; }

sauvegarde() {
  if [ -f "$1" ]; then
    cp "$1" "$1.bak-$(date +%Y%m%d-%H%M%S)"
  fi
}

# Fichiers de config pris à côté du script s'il vient d'un clone du dépôt, sinon sur GitHub
DEPOT_URL="https://raw.githubusercontent.com/Nameless0l/zsh-starship-catppuccin/main"
DEPOT_LOCAL=""
if [ -f "${BASH_SOURCE[0]:-}" ]; then
  DEPOT_LOCAL="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
installer() {
  local tmp
  tmp="$(mktemp)"
  if [ -n "$DEPOT_LOCAL" ] && [ -f "$DEPOT_LOCAL/$1" ]; then
    cp "$DEPOT_LOCAL/$1" "$tmp"
  elif ! curl -fsSL -o "$tmp" "$DEPOT_URL/$1"; then
    : > "$tmp"
  fi
  if [ -s "$tmp" ]; then
    mkdir -p "$(dirname "$2")"
    if ! cmp -s "$tmp" "$2"; then
      sauvegarde "$2"
      cat "$tmp" > "$2"
    fi
    echo "[ok] $2"
  else
    echo "[!!] $1 non récupéré, $2 inchangé"
  fi
  rm -f "$tmp"
}

# Fichier $2 de la dernière release du dépôt GitHub $1, écrit dans $3 seulement si son empreinte
# correspond à celle publiée. VERSION dans $2 devient le numéro de version.
release_github() {
  local tag nom attendu somme
  local auth=()
  tag="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$1/releases/latest")" || return 1
  tag="${tag##*/releases/tag/}"
  case "$tag" in
    "" | */*) return 1 ;;
  esac
  RELEASE_VERSION="${tag#v}"
  nom="${2//VERSION/$RELEASE_VERSION}"
  attendu=""
  for somme in "$nom.sha256" checksums.txt; do
    attendu="$(curl -fsSL "https://github.com/$1/releases/download/$tag/$somme" 2>/dev/null \
      | awk -v n="$nom" '$2 == n || $2 == "*" n { print $1; exit }')"
    if [ -n "$attendu" ]; then
      break
    fi
  done
  if [ -z "$attendu" ]; then
    # Sans fichier d'empreintes dans la release : celle que GitHub calcule, lue dans son API
    # (60 requêtes par heure sans GITHUB_TOKEN)
    if [ -n "${GITHUB_TOKEN:-}" ]; then
      auth=(-H "Authorization: Bearer $GITHUB_TOKEN")
    fi
    attendu="$(curl -fsSL "${auth[@]}" "https://api.github.com/repos/$1/releases/tags/$tag" \
      | awk -v ligne="\"name\": \"$nom\"," '
        index($0, ligne) { vu = 1 }
        vu && !fait && /"digest": "sha256:/ { sub(/.*sha256:/, ""); sub(/".*/, ""); print; fait = 1 }')"
  fi
  if [ -z "$attendu" ]; then
    return 1
  fi
  curl -fsSL -o "$3" "https://github.com/$1/releases/download/$tag/$nom" || return 1
  if [ "$(sha256sum "$3" | cut -d' ' -f1)" != "$attendu" ]; then
    rm -f "$3"
    return 1
  fi
}

# Commande $1 absente : fichier $3 de la dernière release du dépôt $2, binaire $4 dans l'archive
# (vide si le fichier est déjà le binaire), installé dans ~/.local/bin s'il tourne ici
installer_binaire() {
  local tmp binaire
  if command -v "$1" >/dev/null 2>&1; then
    return 0
  fi
  if [ -z "$3" ]; then
    echo "[..] pas de binaire $1 pour $(uname -m)"
    return 0
  fi
  tmp="$(mktemp -d)"
  if release_github "$2" "$3" "$tmp/telechargement"; then
    if [ -z "$4" ]; then
      binaire="$tmp/telechargement"
    else
      binaire="$tmp/${4//VERSION/$RELEASE_VERSION}"
      tar -xzf "$tmp/telechargement" -C "$tmp" 2>/dev/null
    fi
    if [ -f "$binaire" ] && chmod +x "$binaire" && "$binaire" --version >/dev/null 2>&1; then
      install -m 755 "$binaire" "$HOME/.local/bin/$1"
      echo "[ok] $1 $RELEASE_VERSION installé dans ~/.local/bin"
    else
      echo "[!!] $1 téléchargé mais inutilisable sur ce système"
    fi
  else
    echo "[!!] $1 non téléchargé, ou empreinte différente de celle publiée"
  fi
  rm -rf "$tmp"
}

# ---------- Paquets ----------
titre "Paquets apt"
SUDO_OK=0
if command -v apt-get >/dev/null 2>&1; then
  if [ -z "$SUDO" ]; then
    SUDO_OK=1
  elif command -v sudo >/dev/null 2>&1 && sudo -v; then
    SUDO_OK=1
  fi
fi

PAQUETS="git curl zsh zsh-autosuggestions zsh-syntax-highlighting fzf zoxide eza bat git-delta btop fastfetch ripgrep fd-find lazygit nvtop glow hyperfine tmux"
if [ "$SUDO_OK" -eq 1 ]; then
  if command -v add-apt-repository >/dev/null 2>&1; then
    for depot in universe multiverse; do
      if ! $SUDO add-apt-repository -y "$depot"; then
        echo "[!!] dépôt $depot non ajouté, à vérifier à la main"
      fi
    done
  fi
  $SUDO apt-get update
  for p in $PAQUETS; do
    if dpkg -s "$p" >/dev/null 2>&1; then
      continue
    fi
    if ! $SUDO apt-get install -y "$p"; then
      case "$p" in
        eza | lazygit | fastfetch | glow | git-delta) echo "[..] $p absent d'apt, installé autrement plus bas" ;;
        *) echo "[!!] paquet indisponible : $p" ;;
      esac
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

# ---------- Binaires GitHub : outils hors d'apt, ou absents de cette version d'apt ----------
titre "Binaires GitHub"
export PATH="$HOME/.local/bin:$PATH"
mkdir -p "$HOME/.local/bin"
case "$(uname -m)" in
  x86_64)
    LAZYGIT_ARCH="x86_64"; GLOW_ARCH="x86_64"; FASTFETCH_ARCH="amd64"
    DELTA_CIBLE="x86_64-unknown-linux-musl"; ATUIN_CIBLE="x86_64-unknown-linux-musl"; TLDR_CIBLE="x86_64-musl"
    ;;
  aarch64 | arm64)
    LAZYGIT_ARCH="arm64"; GLOW_ARCH="arm64"; FASTFETCH_ARCH="aarch64"
    DELTA_CIBLE="aarch64-unknown-linux-gnu"; ATUIN_CIBLE="aarch64-unknown-linux-musl"; TLDR_CIBLE="aarch64-musl"
    ;;
  armv7l)
    LAZYGIT_ARCH="armv6"; GLOW_ARCH="arm"; FASTFETCH_ARCH="armv7l"
    DELTA_CIBLE="arm-unknown-linux-gnueabihf"; ATUIN_CIBLE=""; TLDR_CIBLE="armv7-musleabihf"
    ;;
  *)
    LAZYGIT_ARCH=""; GLOW_ARCH=""; FASTFETCH_ARCH=""
    DELTA_CIBLE=""; ATUIN_CIBLE=""; TLDR_CIBLE=""
    ;;
esac
installer_binaire lazygit jesseduffield/lazygit "${LAZYGIT_ARCH:+lazygit_VERSION_linux_$LAZYGIT_ARCH.tar.gz}" lazygit
installer_binaire glow charmbracelet/glow "${GLOW_ARCH:+glow_VERSION_Linux_$GLOW_ARCH.tar.gz}" "glow_VERSION_Linux_$GLOW_ARCH/glow"
installer_binaire fastfetch fastfetch-cli/fastfetch "${FASTFETCH_ARCH:+fastfetch-linux-$FASTFETCH_ARCH.tar.gz}" "fastfetch-linux-$FASTFETCH_ARCH/usr/bin/fastfetch"
installer_binaire delta dandavison/delta "${DELTA_CIBLE:+delta-VERSION-$DELTA_CIBLE.tar.gz}" "delta-VERSION-$DELTA_CIBLE/delta"
installer_binaire atuin atuinsh/atuin "${ATUIN_CIBLE:+atuin-$ATUIN_CIBLE.tar.gz}" "atuin-$ATUIN_CIBLE/atuin"
installer_binaire tldr tealdeer-rs/tealdeer "${TLDR_CIBLE:+tealdeer-linux-$TLDR_CIBLE}" ""

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
    $SUDO apt-get install -y gpg
    $SUDO mkdir -p /etc/apt/keyrings
    if curl -fsSL -o /tmp/eza-deb.asc https://raw.githubusercontent.com/eza-community/eza/main/deb.asc; then
      $SUDO gpg --dearmor --yes -o /etc/apt/keyrings/gierens.gpg /tmp/eza-deb.asc
      $SUDO sh -c 'echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" > /etc/apt/sources.list.d/gierens.list'
      $SUDO chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
      $SUDO apt-get update
      $SUDO apt-get install -y eza
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
installer eza/theme.yml "$HOME/.config/eza/theme.yml"

# ---------- ~/.zshrc ----------
titre "~/.zshrc"
installer config/zshrc "$HOME/.zshrc"

# ---------- Starship (prompt deux lignes, Catppuccin Mocha) ----------
titre "starship.toml"
installer config/starship.toml "$HOME/.config/starship.toml"

# ---------- lazygit, btop, delta ----------
titre "lazygit, btop, delta"
installer config/lazygit.yml "$HOME/.config/lazygit/config.yml"

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

# ---------- tmux, atuin, tldr ----------
titre "tmux, atuin, tldr"
if command -v tmux >/dev/null 2>&1; then
  TMUX_CATPPUCCIN="$HOME/.config/tmux/plugins/catppuccin/tmux"
  if [ ! -d "$TMUX_CATPPUCCIN" ]; then
    if ! git -c advice.detachedHead=false clone -q --depth 1 --branch v2.3.2 https://github.com/catppuccin/tmux.git "$TMUX_CATPPUCCIN"; then
      echo "[!!] thème tmux Catppuccin non cloné"
    fi
  fi
  installer config/tmux.conf "$HOME/.config/tmux/tmux.conf"
  if [ -f "$HOME/.tmux.conf" ]; then
    echo "[..] ~/.tmux.conf existe et passe devant ~/.config/tmux/tmux.conf : le renommer pour avoir le thème"
  fi
else
  echo "[..] tmux absent, config tmux sautée"
fi

if command -v atuin >/dev/null 2>&1; then
  installer config/atuin/config.toml "$HOME/.config/atuin/config.toml"
  installer config/atuin/themes/catppuccin-mocha-mauve.toml "$HOME/.config/atuin/themes/catppuccin-mocha-mauve.toml"
  # Une seule fois, tant que la base d'atuin est vide : l'historique zsh existant y entre
  if [ -s "$HOME/.zsh_history" ] && [ -z "$(ATUIN_SESSION="$(atuin uuid)" atuin search --limit 1 --cmd-only 2>/dev/null)" ]; then
    if HISTFILE="$HOME/.zsh_history" atuin import zsh >/dev/null 2>&1; then
      echo "[ok] historique zsh importé dans atuin"
    else
      echo "[!!] import de l'historique dans atuin échoué"
    fi
  fi
fi

if command -v tldr >/dev/null 2>&1; then
  installer config/tealdeer.toml "$HOME/.config/tealdeer/config.toml"
  if [ ! -d "$HOME/.cache/tealdeer" ]; then
    if tldr --update >/dev/null 2>&1; then
      echo "[ok] pages tldr téléchargées"
    else
      echo "[..] pages tldr non téléchargées, elles le seront au premier tldr"
    fi
  fi
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
echo "Se déconnecter puis se reconnecter en SSH pour arriver dans zsh."
echo "Les icônes du prompt viennent de la police du terminal depuis lequel on se connecte :"
echo "la Nerd Font s'installe sur cette machine-là, pas ici."
echo "À essayer : t ouvre tmux, Ctrl+R cherche dans l'historique (atuin), tldr tar donne des exemples."
if [ ! -f "$HOME/.zshrc.local" ]; then
  echo "Les alias et fonctions personnels vont dans ~/.zshrc.local : le script ne le touche jamais."
fi
