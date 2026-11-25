#!/usr/bin/env bash
# Config terminal pour une machine sans écran, atteinte en SSH : zsh, Starship, outils.
# Rien de graphique : pas d'extension GNOME, pas de police, pas de réglage Ptyxis.
# Usage : bash setup-terminal-ssh.sh (sans sudo, il le demande quand il en a besoin ; en root, il s'en passe)
# Sans droits sudo, les paquets sont sautés et le reste s'installe dans ton dossier personnel.
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

PAQUETS="git curl zsh zsh-autosuggestions zsh-syntax-highlighting fzf zoxide eza bat git-delta btop fastfetch ripgrep fd-find lazygit nvtop glow hyperfine"
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
# Pris à côté du script s'il vient d'un clone du dépôt, sinon téléchargé depuis GitHub
THEME_EZA_URL="https://raw.githubusercontent.com/Nameless0l/zsh-starship-catppuccin/main/eza/theme.yml"
THEME_EZA_LOCAL="$(dirname "${BASH_SOURCE[0]}")/eza/theme.yml"
mkdir -p "$HOME/.config/eza"
theme_tmp="$(mktemp)"
if [ -f "$THEME_EZA_LOCAL" ]; then
  cp "$THEME_EZA_LOCAL" "$theme_tmp"
elif ! curl -fsSL -o "$theme_tmp" "$THEME_EZA_URL"; then
  : > "$theme_tmp"
fi
if [ -s "$theme_tmp" ]; then
  if ! cmp -s "$theme_tmp" "$HOME/.config/eza/theme.yml"; then
    sauvegarde "$HOME/.config/eza/theme.yml"
    cp "$theme_tmp" "$HOME/.config/eza/theme.yml"
  fi
  echo "[ok] thème eza installé"
else
  echo "[!!] thème eza non téléchargé, eza garde ses icônes par défaut"
fi
rm -f "$theme_tmp"

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
echo "Déconnecte-toi puis reconnecte-toi en SSH pour arriver dans zsh."
echo "Les icônes du prompt viennent de la police du terminal depuis lequel tu te connectes :"
echo "installe une Nerd Font sur cette machine-là, pas ici."
if [ ! -f "$HOME/.zshrc.local" ]; then
  echo "Tes alias et fonctions perso vont dans ~/.zshrc.local : le script ne le touche jamais."
fi
