# Dotfiles — Agent Deployment Guide

GNU Stow-managed dotfiles. Each top-level directory (except `install/`, `skills/`, `.git/`) is a stow package. When stowed, files within are symlinked into `$HOME`.

## Quick Deploy Pattern

```bash
# 1. Clone
git clone https://github.com/linxichen/dotfiles.git ~/dotfiles
cd ~/dotfiles

# 2. Install GNU Stow (if missing)
brew install stow          # macOS
sudo apt install -y stow   # Debian/Ubuntu
sudo pacman -S stow        # Arch

# 3. Stow a package
stow <package> -t ~

# 4. Unstow / restow
stow <package> -D -t ~   # remove
stow <package> -R -t ~   # restow
```

## Package Manifest

### Editors

| Package | Files | System Deps (debian / arch / macos) | External Setup |
|---|---|---|---|
| **vim** | `.vimrc`, `.gvimrc`, variants | `vim git` | Clone Vundle: `git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim` then `vim +PluginInstall +qall` |
| **nvim** | `.config/nvim/` (LazyVim starter) | `neovim` | None — LazyVim self-bootstraps on first `nvim` launch |
| **emacs** | `.emacs` | `emacs` | None — stow only |
| **spacemacs** | `.spacemacs` | `emacs git` | Clone spacemacs first: `git clone https://github.com/syl20bnr/spacemacs ~/.emacs.d` |
| **doom_emacs** | `config.el`, `init.el`, `packages.el` | `emacs git ripgrep fd` | Clone doom first: `git clone --depth 1 https://github.com/doomemacs/doomemacs ~/.config/emacs` then `~/.config/emacs/bin/doom install` |

### Shell

| Package | Files | System Deps | External Setup |
|---|---|---|---|
| **oh-my-zsh** | `.zshrc` | `zsh git` | Install oh-my-zsh first: `sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended` |
| **ubuntu_profile_d** | shell snippets | — | Copy to `/etc/profile.d/` (needs sudo). Not stowed. |
| **macprofile** | `dotprofile` → `~/.profile` | — | Stow only |

### Terminals

| Package | Files | System Deps | External Setup |
|---|---|---|---|
| **tmux** | `.tmux.conf` | `tmux` | Clone TPM: `git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm` then run `~/.tmux/plugins/tpm/bin/install_plugins` |
| **kitty** | `.config/kitty/` | `kitty` | Stow only |
| **wezterm** | `.wezterm.lua` | `wezterm` | Stow only |

### Window Managers (Linux only)

| Package | Files | System Deps | External Setup |
|---|---|---|---|
| **i3** | `config`, `.Xresources` | `i3-wm i3status rofi` | Stow only |
| **regolith3** | `.config/regolith3/` | `regolith-desktop` | Stow only |

### Misc

| Package | Files | System Deps | External Setup |
|---|---|---|---|
| **w3m** | `keymap` → `~/.w3m/keymap` | `w3m` | Stow only |
| **noip** | `noip.sh` | `build-essential` (build deps for No-IP DUC) | Stow only — script, not a service |
| **aider** | `.aider.conf.yml` | `aider` (pip/brew) | Stow only |

## Platform Detection (for agents)

```bash
# Detect OS
case "$(uname -s)" in
    Linux*)  OS="linux" ;;
    Darwin*) OS="macos" ;;
    *)       OS="unknown" ;;
esac

# Detect package manager
if command -v apt-get &>/dev/null; then PKG="apt"
elif command -v pacman &>/dev/null; then PKG="pacman"
elif command -v brew &>/dev/null; then PKG="brew"
else PKG="unknown"
fi
```

## Deployment Order

When deploying multiple packages, stow in this order to avoid conflicts:

1. **Dependencies first**: `tmux` (TPM), `oh-my-zsh` (framework)
2. **Editors**: `vim`, `nvim`, `emacs`/`spacemacs`/`doom_emacs` (pick ONE emacs variant)
3. **Terminals**: `kitty`, `wezterm`
4. **Window managers**: `i3`, `regolith3` (Linux only)
5. **Everything else**

## Secrets & Sensitive Files

- `.gitignore` excludes `*.key`, `*.pem`, `.env*`, `.secret*`, `shadowsocks/`
- If `~/.secret` or `~/.secrets` exists, source it in shell rc:
  ```bash
  if [ -f "$HOME/.secret" ]; then source "$HOME/.secret"
  elif [ -f "$HOME/.secrets" ]; then source "$HOME/.secrets"; fi
  ```

## Nerd Fonts (optional)

Install for editor icon support: `Hack`, `FiraCode`, `JetBrainsMono`, `Meslo` from [ryanoasis/nerd-fonts](https://github.com/ryanoasis/nerd-fonts).

## Notes for AI Agents

- **All deployment is idempotent**: stow handles existing symlinks gracefully. Use `-R` to restow.
- **LazyVim**: Plugins are stored in `~/.local/share/nvim/` (outside the stow tree). No submodules needed.
- **Stow creates the directory tree**: e.g. `kitty/.config/kitty/kitty.conf` → `~/.config/kitty/kitty.conf`.
- **Manual deploy script backup**: `skills/deploy.sh` is a human-friendly CLI wrapper around the same stow commands. Agents can use it or stow directly.
