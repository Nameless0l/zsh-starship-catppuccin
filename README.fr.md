# Terminal Zsh + Starship pour Ubuntu, WSL et SSH (Catppuccin, icônes Material pour eza)

[![test](https://github.com/Nameless0l/zsh-starship-catppuccin/actions/workflows/test.yml/badge.svg)](https://github.com/Nameless0l/zsh-starship-catppuccin/actions/workflows/test.yml)

Un script qui transforme un terminal Ubuntu neuf en poste de travail rapide et agréable : **Zsh**, un prompt **Starship** sur deux lignes aux couleurs **Catppuccin Mocha**, **fzf** partout, **zoxide** à la place de `cd`, des outils modernes (**eza**, **bat**, **fd**, **ripgrep**, **delta**, **lazygit**, **btop**, **tmux**, **atuin**, **tldr**) et des icônes de fichiers qui ressemblent au **Material Icon Theme de VS Code**.

Trois versions de la même config :

- `setup-terminal.sh` pour **Ubuntu avec bureau GNOME**, avec terminal déroulant et extensions GNOME au choix
- `setup-terminal-wsl.sh` pour **WSL** (Ubuntu sous Windows, Windows Terminal)
- `setup-terminal-ssh.sh` pour un **serveur ou une carte** atteints en SSH (Ubuntu ou Debian), fonctionne avec ou sans sudo, et aussi en root

Chaque script peut être relancé sans risque : tout fichier remplacé est d'abord sauvegardé en `fichier.bak-AAAAMMJJ-HHMMSS`.

> [English version](README.md)

## Installation

À lancer avec un utilisateur normal, sans sudo : le script le demande quand il en a besoin. Le script SSH peut aussi tourner en root, par exemple sur une carte embarquée.

Sur un système minimal sans `curl`, il faut d'abord l'installer : `apt update && apt install -y curl` en root, ou avec `sudo`.

Ubuntu avec GNOME :

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Nameless0l/zsh-starship-catppuccin/main/setup-terminal.sh)
```

WSL :

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Nameless0l/zsh-starship-catppuccin/main/setup-terminal-wsl.sh)
```

Serveur en SSH :

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Nameless0l/zsh-starship-catppuccin/main/setup-terminal-ssh.sh)
```

Il suffit ensuite d'ouvrir un nouveau terminal. Les icônes demandent une **Nerd Font** dans le terminal où s'affiche le shell :

- Ubuntu avec GNOME : JetBrainsMono Nerd Font est installée et appliquée à Ptyxis automatiquement, avec une palette de couleurs Catppuccin Mocha.
- WSL : sous Windows, `winget install -e --id DEVCOM.JetBrainsMonoNerdFont` installe la police. Le script règle ensuite cette police et le jeu de couleurs Catppuccin Mocha dans le `settings.json` de Windows Terminal, après une sauvegarde. Si ce fichier contient des commentaires, il n'y touche pas : la police et les couleurs se règlent alors dans Paramètres, Profils, Apparence.
- SSH : la Nerd Font s'installe sur l'ordinateur **depuis** lequel on se connecte, pas sur le serveur.

## Ce que ça apporte

L'usage au quotidien de chaque outil, avec des exemples : **[guide d'utilisation](docs/GUIDE.fr.md)**.

- **Couleurs du terminal** : une palette `Catppuccin Mocha` est ajoutée à Ptyxis et appliquée à tous ses profils, à la place du fond aubergine d'Ubuntu. Sous WSL, le même jeu de couleurs est appliqué aux profils Ubuntu de Windows Terminal.
- **Prompt Starship** sur deux lignes avec cadre, pastilles arrondies, statut git détaillé, versions des langages, durée des commandes, heure, pastille **Yocto** quand l'environnement BitBake est chargé, et **prompt transitoire** qui réduit les anciens prompts à `❯ commande`.
- **Zsh** : historique de 100 000 lignes partagé et daté, suggestions grisées, coloration syntaxique, **fzf-tab** sur Tab, `cd` remplacé par zoxide (`cd doc` saute dans un dossier déjà visité, `cdi` pour choisir), `↑` et `↓` filtrés par le début de la ligne déjà tapé, raccourcis Ctrl+flèches, Ctrl+Retour arrière, Début et Fin, pages man en couleur.
- **Outils** : `ls`, `ll`, `la`, `lt` avec eza, `cat` avec bat, `fd` et `rg` pour chercher, delta pour `git diff`, `lg` pour lazygit, btop au thème Catppuccin, nvtop, fastfetch, glow, hyperfine.
- **tmux** : `t` ouvre la session `main` ou la rejoint, elle survit donc à une coupure SSH. Barre Catppuccin en haut, souris, `Ctrl+B |` et `Ctrl+B -` pour couper dans le dossier courant, Alt+flèches pour changer de panneau.
- **atuin** : l'historique dans une base locale, Ctrl+R pour y chercher (recherche floue, avec le dossier et le code de retour de chaque commande). L'historique zsh existant est importé une fois, et `↑` garde sa recherche par préfixe. Synchronisation chiffrée entre machines au choix : `atuin register`, puis `atuin login` sur les autres.
- **tldr** (tealdeer) : `tldr tar` donne des exemples courts et concrets, pages gardées en cache pour marcher hors ligne, couleurs Catppuccin.
- **Outils absents d'apt** : quand le système ne les fournit pas (lazygit, fastfetch et glow sur Ubuntu 24.04, delta sur Debian 12), ils viennent de leur dernière release GitHub dans `~/.local/bin`, comme atuin et tldr. Un téléchargement n'est gardé que si son SHA-256 correspond à celui que GitHub publie pour ce fichier et si le binaire tourne sur la machine.
- **fzf** : Ctrl+R pour l'historique quand atuin manque, Ctrl+T pour un fichier avec aperçu, Alt+C pour un dossier avec arborescence.
- **Icônes eza façon VS Code** : le thème reprend tout le mapping du Material Icon Theme, soit environ 1 200 extensions et 3 800 noms de fichiers et de dossiers répartis sur 820 icônes, chacune avec sa couleur exacte. Les fichiers de config sont reconnus par leur nom (`vite.config.ts`, `.prettierrc`, `Cargo.toml`…) et les dossiers sont colorés selon leur nom, y compris les dossiers français (Téléchargements, Bureau, Images, Musique, Vidéos). Quand aucun glyphe Nerd Font ne correspond à une icône Material (environ 160), eza garde son icône avec la couleur Material. Avec le thème, `ls` prend environ 15 ms au lieu de 2 ms, ce qui ne se voit pas. Il faut eza 0.20 ou plus : le script l'installe depuis le dépôt officiel d'eza quand Ubuntu fournit une version plus ancienne.
- **Extensions GNOME** (bureau seulement), réglables en haut de `setup-terminal.sh` : Quake Terminal sur Super+Entrée (`EXT_QUAKE`), Tiling Shell (`EXT_TILING`), Astra Monitor (`EXT_ASTRA`).

Les alias et fonctions personnels vont dans `~/.zshrc.local` : le script ne le touche jamais.

Pour régénérer le thème d'icônes à partir de la dernière version de Material Icon Theme : `bash eza/build.sh`.

## Fichiers de config

Les trois scripts partagent les mêmes fichiers dans `config/` : `zshrc`, `starship.toml`, `lazygit.yml`, `tmux.conf`, `atuin/` et `tealdeer.toml`, plus `eza/theme.yml`. Ils les copient depuis le clone d'où ils sont lancés, ou les téléchargent depuis ce dépôt quand ils passent par `curl`. Un fichier installé n'est sauvegardé puis remplacé que si son contenu a changé.

## Tests

À chaque push, `tests/lint.sh` vérifie la syntaxe bash et zsh, shellcheck et les fichiers TOML, puis chaque script tourne deux fois dans un conteneur neuf : le script SSH sur Ubuntu 24.04 et Debian 12 en root et sur Ubuntu 24.04 sans sudo, le script WSL sur Ubuntu 24.04 et le script bureau sur Ubuntu 26.04 avec sudo. `tests/check.sh` contrôle ensuite les fichiers installés, les raccourcis zsh, le thème eza, tmux, atuin et tldr, et que le second passage n'a rien changé. Les mêmes tests repassent chaque lundi, car les scripts prennent la dernière version de plusieurs outils.

Pour en lancer un en local :

```bash
docker run --rm -v "$PWD:/repo:ro" ubuntu:24.04 bash /repo/tests/container.sh ssh root
```

## Revenir en arrière

Chaque fichier remplacé a une copie `.bak-...` datée à côté de lui. Il suffit de la remettre en place. Pour revenir à bash : `chsh -s /bin/bash`.

Si tmux garde son ancien look, c'est qu'un `~/.tmux.conf` passe devant `~/.config/tmux/tmux.conf` : le renommer, puis lancer `tmux kill-server`. Pour retrouver la recherche d'historique de fzf sur Ctrl+R, il suffit de supprimer atuin : `rm ~/.local/bin/atuin`.

## Licence

MIT
