#!/usr/bin/env bash
# Config terminal et GNOME : zsh, Starship, outils, extensions GNOME.
# Usage : bash setup-terminal.sh (sans sudo, il le demande quand il en a besoin)
# Relançable sans risque : chaque fichier remplacé est d'abord sauvegardé en .bak daté.

if [ "$(id -u)" -eq 0 ]; then
  echo "À lancer sans sudo."
  exit 1
fi

# ---------- Réglages ----------
# 1 = extension installée et active
# 0 = extension non installée (et désactivée si elle est déjà présente)
EXT_QUAKE=1
EXT_TILING=0
EXT_ASTRA=0
NERD_FONT="JetBrainsMono"
export EXT_QUAKE EXT_TILING EXT_ASTRA

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
for depot in universe multiverse; do
  if ! sudo add-apt-repository -y "$depot"; then
    echo "[!!] dépôt $depot non ajouté, à vérifier à la main"
  fi
done
sudo apt-get update

PAQUETS="git curl zsh zsh-autosuggestions zsh-syntax-highlighting fzf zoxide eza bat git-delta btop fastfetch ripgrep fd-find lazygit nvtop glow hyperfine tmux"
for p in $PAQUETS; do
  if dpkg -s "$p" >/dev/null 2>&1; then
    continue
  fi
  if ! sudo apt-get install -y "$p"; then
    case "$p" in
      eza | lazygit | fastfetch | glow | git-delta) echo "[..] $p absent d'apt, installé autrement plus bas" ;;
      *) echo "[!!] paquet indisponible : $p" ;;
    esac
  fi
done

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

# ---------- Police Nerd Font (pour les icônes du prompt) ----------
titre "Police $NERD_FONT Nerd Font"
if [ -z "$(fc-list ":family=$NERD_FONT Nerd Font")" ]; then
  mkdir -p "$HOME/.local/share/fonts"
  if curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$NERD_FONT.tar.xz" -o /tmp/nerdfont.tar.xz; then
    tar -xf /tmp/nerdfont.tar.xz -C "$HOME/.local/share/fonts"
    fc-cache -f
  else
    echo "[!!] police non téléchargée"
  fi
fi

# Police appliquée à Ptyxis
POLICE_PTYXIS="$NERD_FONT Nerd Font Medium 13"
POLICE_MANUELLE=1
if [ -n "$DBUS_SESSION_BUS_ADDRESS" ] && [ -n "$(fc-list ":family=$NERD_FONT Nerd Font")" ]; then
  if gsettings writable org.gnome.Ptyxis font-name >/dev/null 2>&1; then
    gsettings set org.gnome.Ptyxis use-system-font false
    if gsettings set org.gnome.Ptyxis font-name "$POLICE_PTYXIS"; then
      POLICE_MANUELLE=0
      echo "[ok] Ptyxis : $POLICE_PTYXIS"
    fi
  fi
fi

# ---------- Couleurs du terminal : palette Catppuccin Mocha pour Ptyxis ----------
titre "Palette Ptyxis"
PALETTE_NOM="Catppuccin Mocha"
PALETTE_DIR="$HOME/.local/share/org.gnome.Ptyxis/palettes"
mkdir -p "$PALETTE_DIR"
cat > "$PALETTE_DIR/$PALETTE_NOM.palette" << 'PALETTE_EOF'
[Palette]
Name=Catppuccin Mocha
Background=#1E1E2E
Foreground=#CDD6F4
Cursor=#F5E0DC
Color0=#45475A
Color1=#F38BA8
Color2=#A6E3A1
Color3=#F9E2AF
Color4=#89B4FA
Color5=#F5C2E7
Color6=#94E2D5
Color7=#BAC2DE
Color8=#585B70
Color9=#F38BA8
Color10=#A6E3A1
Color11=#F9E2AF
Color12=#89B4FA
Color13=#F5C2E7
Color14=#94E2D5
Color15=#A6ADC8
PALETTE_EOF

# Appliquée à tous les profils Ptyxis, sinon il garde sa palette par défaut
PALETTE_MANUELLE=1
if [ -n "$DBUS_SESSION_BUS_ADDRESS" ] && gsettings writable org.gnome.Ptyxis profile-uuids >/dev/null 2>&1; then
  uuids="$(gsettings get org.gnome.Ptyxis profile-uuids)"
  uuids="${uuids#@as }"
  uuids="${uuids//[\[\]\',]/ }"
  if [ -z "${uuids// /}" ]; then
    # Ptyxis jamais ouvert : son premier profil est créé ici, comme il le ferait lui-même
    uuids="$(tr -d '-' < /proc/sys/kernel/random/uuid)"
    gsettings set org.gnome.Ptyxis profile-uuids "['$uuids']"
    gsettings set org.gnome.Ptyxis default-profile-uuid "$uuids"
  fi
  for u in $uuids; do
    if gsettings set "org.gnome.Ptyxis.Profile:/org/gnome/Ptyxis/Profiles/$u/" palette "'$PALETTE_NOM'"; then
      PALETTE_MANUELLE=0
    fi
  done
fi
if [ "$PALETTE_MANUELLE" -eq 0 ]; then
  echo "[ok] Ptyxis : palette $PALETTE_NOM"
fi

# ---------- fzf-tab ----------
titre "fzf-tab"
if [ ! -d "$HOME/.zsh/fzf-tab" ]; then
  git clone --depth 1 https://github.com/Aloxaf/fzf-tab "$HOME/.zsh/fzf-tab"
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

# ---------- Extensions GNOME ----------
titre "Extensions GNOME"
if [ -n "$DBUS_SESSION_BUS_ADDRESS" ] && command -v gnome-extensions >/dev/null 2>&1; then
python3 - << 'PY_EOF'
import json
import os
import re
import subprocess
import time

EXT_DIR = os.path.expanduser("~/.local/share/gnome-shell/extensions")
HWMON = "/sys/class/hwmon"

QUAKE = "quake-terminal@diegodario88.github.io"
TILING = "tilingshell@ferrarodomenico.com"
ASTRA = "monitor@astraext.github.io"

SOUHAITE = {
    QUAKE: os.environ.get("EXT_QUAKE", "1") == "1",
    TILING: os.environ.get("EXT_TILING", "0") == "1",
    ASTRA: os.environ.get("EXT_ASTRA", "0") == "1",
}


def run(*cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True)
    except FileNotFoundError:
        return subprocess.CompletedProcess(cmd, 127, "", f"{cmd[0]} introuvable")


def read(path):
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return None


def presente(uuid):
    return os.path.isdir(os.path.join(EXT_DIR, uuid, "schemas"))


def install(uuid):
    if presente(uuid):
        print(f"[ok] déjà installée : {uuid}")
        return
    print(f"[..] {uuid} : cliquer sur Installer dans la fenêtre qui s'ouvre")
    r = run("gdbus", "call", "--session", "--timeout", "300",
            "--dest", "org.gnome.Shell.Extensions",
            "--object-path", "/org/gnome/Shell/Extensions",
            "--method", "org.gnome.Shell.Extensions.InstallRemoteExtension", uuid)
    print("     ", (r.stdout or r.stderr).strip())
    # Les réglages ne s'appliquent qu'une fois l'extension réellement présente
    fin = time.time() + 60
    while not presente(uuid) and time.time() < fin:
        time.sleep(1)


def gset(uuid, schema, key, value):
    sd = os.path.join(EXT_DIR, uuid, "schemas")
    if not os.path.isdir(sd):
        print(f"[!!] {uuid} absente, réglage {key} ignoré")
        return
    if not os.path.exists(os.path.join(sd, "gschemas.compiled")):
        run("glib-compile-schemas", sd)
    r = run("gsettings", "--schemadir", sd, "set", schema, key, value)
    if r.returncode:
        print(f"[!!] {key} : {r.stderr.strip()}")


def gvariant_str(text):
    return "'" + text.replace("\\", "\\\\").replace("'", "\\'") + "'"


def nvidia_gpu(lspci_output):
    for line in lspci_output.splitlines():
        if "[10de:" not in line:
            continue
        if not any(c in line for c in ("VGA compatible controller", "3D controller", "Display controller")):
            continue
        m = re.match(r"^((?:[0-9a-fA-F]{4}:)?[0-9a-fA-F]{2}):([0-9a-fA-F]{2})\.([0-9a-fA-F]) ", line)
        ids = re.search(r"\[10de:([0-9a-fA-F]{4})\]", line)
        if m and ids:
            domain = m.group(1) if ":" in m.group(1) else "0000:" + m.group(1)
            return {"domain": domain, "bus": m.group(2), "slot": m.group(3),
                    "vendorId": "10de", "productId": ids.group(1)}
    return None


def cpu_temp_sensor(hwmon_dir=HWMON):
    if not os.path.isdir(hwmon_dir):
        return None
    for h in sorted(os.listdir(hwmon_dir)):
        base = os.path.join(hwmon_dir, h)
        name = read(os.path.join(base, "name"))
        if name != "coretemp":
            continue
        key = name
        addr = read(os.path.join(base, "device", "address"))
        if addr:
            addr = re.sub(r"^0+:", "", addr)
            addr = re.sub(r"\.[0-9]*$", "", addr)
            key = f"{name}-{{${addr.replace(':', '')}}}"
        else:
            dev = read(os.path.join(base, "device", "device"))
            if dev:
                key = f"{name}-{{${re.sub(r'^0x', '', dev)}}}"
        for f in sorted(os.listdir(base)):
            if re.fullmatch(r"temp\d+_label", f) and read(os.path.join(base, f)) == "Package id 0":
                return {"service": "hwmon", "path": [key, "Package id 0", "input"]}
    return None


def regler_quake():
    # Ptyxis sur Super+Entrée, sur l'écran où se trouve la souris
    qs = "org.gnome.shell.extensions.quake-terminal"
    gset(QUAKE, qs, "terminal-id", "'org.gnome.Ptyxis.desktop'")
    gset(QUAKE, qs, "terminal-shortcut", "['<Super>Return']")
    gset(QUAKE, qs, "render-on-current-monitor", "true")


def regler_tiling():
    # Tuilage automatique, Super+Alt+flèches change le focus
    ts = "org.gnome.shell.extensions.tilingshell"
    gset(TILING, ts, "enable-autotiling", "true")
    for d, k in (("right", "Right"), ("left", "Left"), ("up", "Up"), ("down", "Down")):
        gset(TILING, ts, f"focus-window-{d}", f"['<Super><Alt>{k}']")


def regler_astra():
    # CPU, RAM, GPU NVIDIA et température, sans disque ni réseau
    am = "org.gnome.shell.extensions.astra-monitor"
    for key, val in (("processor-header-show", "true"), ("memory-header-show", "true"),
                     ("storage-header-show", "false"), ("network-header-show", "false")):
        gset(ASTRA, am, key, val)

    gpu = nvidia_gpu(run("lspci", "-nn").stdout)
    if gpu:
        gset(ASTRA, am, "gpu-main", gvariant_str(json.dumps(gpu)))
        gset(ASTRA, am, "gpu-data", gvariant_str(json.dumps([dict(gpu, monitor=True)])))
        gset(ASTRA, am, "gpu-header-show", "true")
        print(f"[ok] GPU NVIDIA configuré ({gpu['domain']}:{gpu['bus']}.{gpu['slot']})")
    else:
        print("[..] Pas de GPU NVIDIA trouvé par lspci")

    sensor = cpu_temp_sensor()
    if sensor:
        gset(ASTRA, am, "sensors-header-sensor1", gvariant_str(json.dumps(sensor)))
        gset(ASTRA, am, "sensors-header-sensor1-show", "true")
        gset(ASTRA, am, "sensors-header-show", "true")
        print("[ok] Température CPU configurée (Package id 0)")
    else:
        print("[..] Capteur coretemp introuvable")


def main():
    # Seules les extensions réglées à 1 sont installées
    for uuid, actif in SOUHAITE.items():
        if actif:
            install(uuid)

    # Réglages des extensions présentes, actives ou non
    for uuid, regler in ((QUAKE, regler_quake), (TILING, regler_tiling), (ASTRA, regler_astra)):
        if presente(uuid):
            regler()

    # Tuilage intégré d'Ubuntu : coupé si Tiling Shell est voulu, rallumé sinon
    for uuid in run("gnome-extensions", "list").stdout.split():
        if uuid.startswith("tiling-assistant@"):
            if SOUHAITE[TILING]:
                run("gnome-extensions", "disable", uuid)
                print(f"[ok] désactivée : {uuid}")
            else:
                run("gnome-extensions", "enable", uuid)
                print(f"[ok] active : {uuid}")

    # Active ou désactive chaque extension (off puis on pour relire les réglages)
    for uuid, actif in SOUHAITE.items():
        if not presente(uuid):
            print(f"[..] {uuid} : non installée (réglée à 0)")
            continue
        run("gnome-extensions", "disable", uuid)
        if actif:
            run("gnome-extensions", "enable", uuid)
        print(f"[ok] {uuid} : {'active' if actif else 'désactivée'}")


main()
PY_EOF
else
  echo "[..] Pas de session GNOME détectée, étape extensions ignorée"
fi

titre "Terminé"
echo "Fermer la session, se reconnecter, puis ouvrir un terminal."
if [ "$POLICE_MANUELLE" -eq 1 ]; then
  echo "Choisir la police $POLICE_PTYXIS dans les préférences de Ptyxis."
fi
if [ "$PALETTE_MANUELLE" -eq 1 ]; then
  echo "Choisir la palette $PALETTE_NOM dans les préférences de Ptyxis (Apparence)."
fi
echo "À essayer : t ouvre tmux, Ctrl+R cherche dans l'historique (atuin), tldr tar donne des exemples."
if [ ! -f "$HOME/.zshrc.local" ]; then
  echo "Les alias et fonctions personnels vont dans ~/.zshrc.local : le script ne le touche jamais."
fi
