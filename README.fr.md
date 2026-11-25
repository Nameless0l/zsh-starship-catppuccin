# Terminal Zsh + Starship pour Ubuntu, WSL et SSH (Catppuccin, icônes Material pour eza)

Un script qui transforme un terminal Ubuntu neuf en poste de travail rapide et agréable : **Zsh**, un prompt **Starship** sur deux lignes aux couleurs **Catppuccin Mocha**, **fzf** partout, **zoxide** à la place de `cd`, des outils modernes (**eza**, **bat**, **fd**, **ripgrep**, **delta**, **lazygit**, **btop**) et des icônes de fichiers qui ressemblent au **Material Icon Theme de VS Code**.

Trois versions de la même config :

- `setup-terminal.sh` pour **Ubuntu avec bureau GNOME**, avec terminal déroulant et extensions GNOME au choix
- `setup-terminal-wsl.sh` pour **WSL** (Ubuntu sous Windows, Windows Terminal)
- `setup-terminal-ssh.sh` pour un **serveur sans écran** atteint en SSH, fonctionne même sans sudo

Chaque script peut être relancé sans risque : tout fichier remplacé est d'abord sauvegardé en `fichier.bak-AAAAMMJJ-HHMMSS`.

> [English version](README.md)

## Installation

À lancer avec ton utilisateur normal, sans sudo : le script le demande quand il en a besoin.

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

Ouvre ensuite un nouveau terminal. Les icônes demandent une **Nerd Font** dans le terminal que tu regardes :

- Ubuntu avec GNOME : JetBrainsMono Nerd Font est installée et appliquée à Ptyxis automatiquement, avec une palette de couleurs Catppuccin Mocha.
- WSL : sous Windows, lance `winget install -e --id DEVCOM.JetBrainsMonoNerdFont`. Le script règle ensuite cette police et le jeu de couleurs Catppuccin Mocha dans le `settings.json` de Windows Terminal, après une sauvegarde. Si ce fichier contient des commentaires, il n'y touche pas : règle alors la police et les couleurs dans Paramètres, Profils, Apparence.
- SSH : installe une Nerd Font sur l'ordinateur **depuis** lequel tu te connectes, pas sur le serveur.

## Ce que ça apporte

- **Couleurs du terminal** : une palette `Catppuccin Mocha` est ajoutée à Ptyxis et appliquée à tous ses profils, à la place du fond aubergine d'Ubuntu. Sur une installation neuve, ouvre Ptyxis une fois avant de lancer le script, pour qu'un profil existe. Sous WSL, le même jeu de couleurs est appliqué aux profils Ubuntu de Windows Terminal.
- **Prompt Starship** sur deux lignes avec cadre, pastilles arrondies, statut git détaillé, versions des langages, durée des commandes, heure, pastille **Yocto** quand l'environnement BitBake est chargé, et **prompt transitoire** qui réduit les anciens prompts à `❯ commande`.
- **Zsh** : historique de 100 000 lignes partagé et daté, suggestions grisées, coloration syntaxique, **fzf-tab** sur Tab, `cd` remplacé par zoxide (`cd doc` saute dans un dossier déjà visité, `cdi` pour choisir), `↑` et `↓` filtrés par ce que tu as tapé, raccourcis Ctrl+flèches, Ctrl+Retour arrière, Début et Fin, pages man en couleur.
- **Outils** : `ls`, `ll`, `la`, `lt` avec eza, `cat` avec bat, `fd` et `rg` pour chercher, delta pour `git diff`, `lg` pour lazygit, btop au thème Catppuccin, nvtop, fastfetch, glow, hyperfine.
- **fzf** : Ctrl+R pour l'historique, Ctrl+T pour un fichier avec aperçu, Alt+C pour un dossier avec arborescence.
- **Icônes eza façon VS Code** : 143 extensions, 49 noms de fichiers et 80 noms de dossiers ont leur icône, avec les couleurs exactes du Material Icon Theme. Les dossiers sont colorés selon leur nom, y compris les dossiers français (Téléchargements, Bureau, Images, Musique, Vidéos). Il faut eza 0.20 ou plus : le script l'installe depuis le dépôt officiel d'eza quand Ubuntu fournit une version plus ancienne.
- **Extensions GNOME** (bureau seulement), réglables en haut de `setup-terminal.sh` : Quake Terminal sur Super+Entrée (`EXT_QUAKE`), Tiling Shell (`EXT_TILING`), Astra Monitor (`EXT_ASTRA`).

Tes alias et fonctions perso vont dans `~/.zshrc.local` : le script ne le touche jamais.

Pour régénérer le thème d'icônes à partir de la dernière version de Material Icon Theme : `bash eza/build.sh`.

## Revenir en arrière

Chaque fichier remplacé a une copie `.bak-...` datée à côté de lui. Il suffit de la remettre en place. Pour revenir à bash : `chsh -s /bin/bash`.

## Licence

MIT
