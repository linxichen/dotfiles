# Dotfiles Skills

This directory contains reusable scripts/skills for deploying dotfiles configurations on new systems.

## Available Skills

### `deploy.sh` - Dotfiles Deployment Script

A comprehensive deployment script that uses GNU Stow to symlink configuration files to your home directory.

#### Usage

```bash
# Make the script executable
chmod +x skills/deploy.sh

# Deploy a specific package
./skills/deploy.sh <package>

# Show help
./skills/deploy.sh --help
```

#### Available Packages

- **tmux** - Tmux configuration with plugin manager (TPM)
- **oh-my-zsh** - Oh My Zsh shell configuration
- **vim** - Vim editor configuration
- **nvim/kickstart.nvim** - Neovim configuration (kickstart.nvim fork)
- **emacs** - GNU Emacs configuration
- **spacemacs** - Spacemacs configuration
- **doom_emacs** - Doom Emacs configuration
- **kitty** - Kitty terminal emulator configuration
- **wezterm** - WezTerm terminal configuration
- **i3** - i3 window manager configuration
- **regolith3** - Regolith 3 (i3-gaps) configuration
- **w3m** - w3m text browser configuration
- **noip** - No-IP DUC configuration
- **shadowsocks** - Shadowsocks proxy configuration

#### Examples

```bash
# Deploy tmux configuration
./skills/deploy.sh tmux

# Deploy oh-my-zsh
./skills/deploy.sh oh-my-zsh

# Deploy any other package
./skills/deploy.sh vim
```

#### Features

- **Automatic dependency installation** - Installs GNU Stow if not present
- **Package manager detection** - Works with apt-get, yum, dnf, pacman, and brew
- **Plugin management** - Automatically installs tmux plugin manager (TPM) for tmux
- **Error handling** - Comprehensive validation and error messages
- **Safe deployment** - Validates package names and checks directory existence

## How It Works

The deployment script uses GNU Stow to create symlinks from files in each package directory to your home directory (`~`).

For example, if you have:
```
tmux/.tmux.conf
tmux/.tmux/
```

After running `./skills/deploy.sh tmux`, you'll have:
```
~/.tmux.conf -> ~/dotfiles/tmux/.tmux.conf
~/.tmux/ -> ~/dotfiles/tmux/.tmux/
```

## Unstowing/Re-stowing Packages

If you need to remove or re-deploy a package:

```bash
# Delete (unstow) a package
stow <package> -D -t ~

# Re-stow a package
stow <package> -R -t ~
```

## Setup on New Computers

1. Clone the repository (with submodules):
   ```bash
   git clone --recurse-submodules https://github.com/linxichen/dotfiles.git
   cd dotfiles
   ```

2. Make the deploy script executable:
   ```bash
   chmod +x skills/deploy.sh
   ```

3. Deploy packages as needed:
   ```bash
   ./skills/deploy.sh tmux
   ./skills/deploy.sh oh-my-zsh
   ```

## Integration with Claude Code

You can invoke this skill directly from Claude Code by referencing the script:

```
Run ./skills/deploy.sh tmux to deploy tmux configuration
```

Or create a custom slash command in your Claude Code settings for quick access.
