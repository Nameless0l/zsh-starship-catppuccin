# Zsh + Starship terminal setup for Ubuntu, WSL and SSH (Catppuccin, eza Material icons)

One script to turn a fresh Ubuntu terminal into a fast, good-looking and keyboard-friendly workspace: **Zsh**, a two-line **Starship** prompt in **Catppuccin Mocha**, **fzf** everywhere, **zoxide** smart `cd`, modern CLI tools (**eza**, **bat**, **fd**, **ripgrep**, **delta**, **lazygit**, **btop**) and file icons that look like the **VS Code Material Icon Theme**.

Three flavours of the same config:

- `setup-terminal.sh` for **Ubuntu desktop (GNOME)**, with a drop-down terminal and optional GNOME extensions
- `setup-terminal-wsl.sh` for **WSL** (Ubuntu on Windows, Windows Terminal)
- `setup-terminal-ssh.sh` for **headless servers** reached over SSH, works without sudo

Every script can be run again safely: each file it replaces is first saved as `file.bak-YYYYMMDD-HHMMSS`.

> Script comments and messages are in French. [Version française du README](README.fr.md).

## Quick start

Run as your normal user (not with sudo, the script asks for it when needed).

Ubuntu desktop (GNOME):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Nameless0l/zsh-starship-catppuccin/main/setup-terminal.sh)
```

WSL:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Nameless0l/zsh-starship-catppuccin/main/setup-terminal-wsl.sh)
```

Server over SSH:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Nameless0l/zsh-starship-catppuccin/main/setup-terminal-ssh.sh)
```

Then open a new terminal. Icons need a **Nerd Font** in the terminal you are looking at:

- Ubuntu desktop: JetBrainsMono Nerd Font is installed and applied to Ptyxis automatically, together with a Catppuccin Mocha color palette.
- WSL: on Windows, run `winget install -e --id DEVCOM.JetBrainsMonoNerdFont`. The script then sets this font and a Catppuccin Mocha color scheme in Windows Terminal's `settings.json` (backed up first). If that file contains comments it is left untouched: set the font and color scheme in Settings, Profiles, Appearance.
- SSH: install a Nerd Font on the computer you connect **from**, not on the server.

## What you get

### Terminal colors

- **Ptyxis** (Ubuntu desktop): a `Catppuccin Mocha` palette is added to `~/.local/share/org.gnome.Ptyxis/palettes/` and applied to every existing profile, replacing Ubuntu's aubergine background. Open Ptyxis once before running the script on a brand-new install, so that a profile exists.
- **Windows Terminal** (WSL): the official Catppuccin Mocha scheme is added and applied to the Ubuntu and WSL profiles.

### Starship prompt (Catppuccin Mocha)

- Two-line prompt with a `╭─` / `╰─` frame, rounded "pill" segments and a line filling the gap
- OS icon, user, host (only over SSH), directory, git branch and detailed git status (`⇡2 !3 ?1`), added and deleted lines
- Language versions for C, Python, Node.js, PHP and Rust
- Right side: duration of long commands, exit code, background jobs, sudo indicator, time
- **Yocto / BitBake badge** when `oe-init-build-env` has been sourced (shows the build directory)
- **Transient prompt**: once a command runs, its prompt collapses to `❯ command`, so scrollback stays readable

### Zsh

- 100 000-line shared history with timestamps, no duplicates, `" command"` not saved
- **zsh-autosuggestions** (history and completion) and **zsh-syntax-highlighting**
- **fzf-tab**: Tab opens fzf with a preview of the folder content
- **zoxide replaces `cd`**: `cd doc` jumps to a folder you already visited, `cdi` picks one with fzf
- `↑` and `↓` only browse commands that start like what you typed
- Ctrl+← / Ctrl+→ by word, Ctrl+Backspace and Ctrl+Delete delete a word, Home and End work, Ctrl+X Ctrl+E edits the command in your editor
- Colored man pages
- Your own aliases and functions go in `~/.zshrc.local`, which the scripts never touch

### Modern command-line tools

- `ls`, `ll`, `la`, `lt` use **eza** (icons, git status, folders first, tree view)
- `cat` uses **bat** (syntax highlighting)
- `fd` (fd-find) and `rg` (ripgrep) for fast search, used by fzf and Ctrl+T
- **git-delta** for colored `git diff` with line numbers
- `lg` opens **lazygit** with a Catppuccin theme
- **btop** with the Catppuccin Mocha theme, **nvtop**, **fastfetch**, **glow**, **hyperfine**

### fzf key bindings

- Ctrl+R: search history
- Ctrl+T: search a file, with a bat preview
- Alt+C: jump to a folder, with a tree preview

### eza icons like the VS Code Material Icon Theme

`eza/theme.yml` gives 143 file extensions, 49 file names and 80 folder names their own icon, colored with the exact colors of the VS Code **Material Icon Theme** (read from its SVG files). Glyphs come from the Material Design set of Nerd Fonts. Folders are colored by name like in VS Code: `src`, `docs`, `tests`, `.git`, `node_modules`, `Downloads`, French home folders, and more. Yocto files (`.bb`, `.bbappend`, `local.conf`) and device trees (`.dts`) are covered too.

A terminal can only show single-color font glyphs, so the icons are not the VS Code SVGs themselves, but the result is close. It needs **eza 0.20 or newer**: the scripts install it from the official eza repository (deb.gierens.de) when Ubuntu ships an older version, as Ubuntu 24.04 does.

To use only the theme:

```bash
mkdir -p ~/.config/eza
curl -fsSL -o ~/.config/eza/theme.yml https://raw.githubusercontent.com/Nameless0l/zsh-starship-catppuccin/main/eza/theme.yml
```

If `LS_COLORS` is set (it is on Ubuntu), eza lets it override the theme. The config clears it for eza only: `eza() { LS_COLORS= command eza "$@"; }`.

To rebuild the theme from the latest Material Icon Theme: `bash eza/build.sh`.

### GNOME extras (Ubuntu desktop only)

Set at the top of `setup-terminal.sh`, 1 to install and enable, 0 to skip:

- `EXT_QUAKE=1`: **Quake Terminal**, a drop-down Ptyxis on Super+Enter
- `EXT_TILING=0`: **Tiling Shell** (when enabled, Ubuntu's built-in tiling is turned off to avoid conflicts)
- `EXT_ASTRA=0`: **Astra Monitor**, CPU, RAM, NVIDIA GPU and temperature in the top bar

## Requirements

- Ubuntu 24.04 or newer (a package missing from your release is skipped with a `[!!]` line)
- `sudo` for packages; without it the SSH script still installs Starship, the zsh plugins and the config in your home folder
- Internet access to the Ubuntu archive, GitHub and starship.rs

## Undo

Every replaced file has a dated `.bak-...` copy next to it (`~/.zshrc`, `~/.config/starship.toml`, `~/.config/eza/theme.yml`, `~/.config/lazygit/config.yml`). Copy it back to return to your previous setup. To go back to bash: `chsh -s /bin/bash`.

## FAQ

**Icons show as squares or `�`.** The terminal font is not a Nerd Font. See Quick start.

**`ls` shows icons but not the Material colors.** Check `eza --version` (0.20 or newer is needed) and that `~/.config/eza/theme.yml` exists. eza silently ignores a theme file it cannot read.

**Can I keep my own aliases?** Yes, put them in `~/.zshrc.local`. `~/.shell_common` is loaded too, if you share aliases with bash.

## Credits

[Starship](https://starship.rs), [Catppuccin](https://catppuccin.com), [eza](https://github.com/eza-community/eza), [Nerd Fonts](https://www.nerdfonts.com), [fzf](https://github.com/junegunn/fzf), [fzf-tab](https://github.com/Aloxaf/fzf-tab), [zoxide](https://github.com/ajeetdsouza/zoxide), [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions), [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting), [Material Icon Theme](https://github.com/material-extensions/vscode-material-icon-theme) for the icon colors, [Quake Terminal](https://github.com/diegodario88/quake-terminal), [Tiling Shell](https://github.com/domferr/tilingshell), [Astra Monitor](https://github.com/AstraExt/astra-monitor).

## License

MIT
