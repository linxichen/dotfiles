#!/bin/bash
# Interactive Dotfiles Deployment Script
# Supports: Ubuntu/Debian, Arch Linux, macOS
# TUI: whiptail
#
# Usage:
#   ./interactive-deploy.sh                    # Interactive mode
#   ./interactive-deploy.sh --dry-run tmux vim # Dry-run with specified packages
#   ./interactive-deploy.sh --dry-run          # Dry-run (shows package selection)

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false
REQUESTED_PACKAGES=()

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run|-n)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS] [packages...]"
            echo ""
            echo "Options:"
            echo "  --dry-run, -n    Show what would be installed without actually installing"
            echo "  --help, -h       Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                           # Interactive mode with package selection"
            echo "  $0 --dry-run tmux vim        # Show what would be installed"
            echo "  $0 --dry-run                 # Dry-run with package selection TUI"
            exit 0
            ;;
        *)
            # Collect package names
            REQUESTED_PACKAGES+=("$1")
            shift
            ;;
    esac
done

# Color codes
if [[ -t 1 ]] && command -v tput &>/dev/null && tput colors &>/dev/null; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4)
    BOLD=$(tput bold)
    NC=$(tput sgr0)
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    BOLD=''
    NC=''
fi

# ============================================================================
# DRY RUN HELPERS
# ============================================================================

run_cmd() {
    local cmd="$*"

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${BOLD}[DRY RUN]${NC} ${BLUE}$cmd${NC}"
    else
        eval "$cmd"
    fi
}

sudo_run() {
    local cmd="$*"

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${BOLD}[DRY RUN]${NC} ${BLUE}sudo $cmd${NC}"
    else
        sudo eval "$cmd"
    fi
}

# ============================================================================
# OS DETECTION
# ============================================================================

detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [[ -f /etc/debian_version ]]; then
            echo "debian"
        elif [[ -f /etc/arch-release ]]; then
            echo "arch"
        elif [[ -f /etc/fedora-release ]]; then
            echo "fedora"
        else
            echo "unknown_linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "unknown"
    fi
}

OS=$(detect_os)

# Package managers
case "$OS" in
    debian)
        PKG_MANAGER="apt-get"
        PKG_UPDATE="sudo apt-get update"
        PKG_INSTALL="sudo apt-get install -y"
        ;;
    arch)
        PKG_MANAGER="pacman"
        PKG_UPDATE="sudo pacman -Sy"
        PKG_INSTALL="sudo pacman -S --noconfirm --needed"
        ;;
    macos)
        if ! command -v brew &>/dev/null; then
            echo "Error: Homebrew not found. Please install from https://brew.sh"
            exit 1
        fi
        PKG_MANAGER="brew"
        PKG_UPDATE="brew update"
        PKG_INSTALL="brew install"
        ;;
    *)
        echo "Error: Unsupported operating system"
        exit 1
        ;;
esac

# ============================================================================
# PACKAGE DEFINITIONS
# ============================================================================

# Packages with dependencies for each OS
declare -A PACKAGES

# tmux
PACKAGES[tmux_debian]="tmux xsel libevent-dev"
PACKAGES[tmux_arch]="tmux xsel"
PACKAGES[tmux_macos]="tmux"

# vim
PACKAGES[vim_debian]="vim git python3 python3-pip ruby ruby-dev"
PACKAGES[vim_arch]="vim git python python-pip ruby"
PACKAGES[vim_macos]="vim git python3 ruby"

# nvim
PACKAGES[nvim_debian]="neovim git python3 python3-pip nodejs npm"
PACKAGES[nvim_arch]="neovim git python python-pip nodejs npm"
PACKAGES[nvim_macos]="neovim git python3 node"

# emacs
PACKAGES[emacs_debian]="emacs git build-essential autoconf make"
PACKAGES[emacs_arch]="emacs git base-devel"
PACKAGES[emacs_macos]="emacs git"

# spacemacs
PACKAGES[spacemacs_debian]="emacs git build-essential"
PACKAGES[spacemacs_arch]="emacs git base-devel"
PACKAGES[spacemacs_macos]="emacs git"

# doom_emacs
PACKAGES[doom_emacs_debian]="emacs git ripgrep tree-sitter"
PACKAGES[doom_emacs_arch]="emacs git ripgrep tree-sitter"
PACKAGES[doom_emacs_macos]="emacs git ripgrep"

# kitty
PACKAGES[kitty_debian]="kitty"
PACKAGES[kitty_arch]="kitty"
PACKAGES[kitty_macos]="kitty"

# wezterm
PACKAGES[wezterm_debian]="wezterm"
PACKAGES[wezterm_arch]="wezterm"
PACKAGES[wezterm_macos]="wezterm"

# i3
PACKAGES[i3_debian]="i3 i3status rofi compton feh dunst x11-xserver-utils"
PACKAGES[i3_arch]="i3-wm i3status rofi picom feh dunst xorg-xrandr"
PACKAGES[i3_macos]=""

# regolith3
PACKAGES[regolith3_debian]="regolith-desktop i3status rofi"
PACKAGES[regolith3_arch]=""
PACKAGES[regolith3_macos]=""

# oh-my-zsh
PACKAGES[oh-my-zsh_debian]="zsh git"
PACKAGES[oh-my-zsh_arch]="zsh git"
PACKAGES[oh-my-zsh_macos]="zsh git"

# w3m
PACKAGES[w3m_debian]="w3m"
PACKAGES[w3m_arch]="w3m"
PACKAGES[w3m_macos]="w3m"

# noip
PACKAGES[noip_debian]="build-essential"
PACKAGES[noip_arch]="base-devel"
PACKAGES[noip_macos]=""

# ============================================================================
# EXTERNAL REPOSITORIES
# ============================================================================

install_tmux_plugins() {
    local tpm_dir="$HOME/.tmux/plugins/tpm"
    if [[ ! -d "$tpm_dir" ]]; then
        echo -e "${YELLOW}Installing tmux plugin manager (TPM)...${NC}"
        run_cmd "mkdir -p $HOME/.tmux/plugins"
        run_cmd "git clone https://github.com/tmux-plugins/tpm $tpm_dir"
        run_cmd "$tpm_dir/bin/install_plugins"
    fi
}

install_oh_my_zsh() {
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        echo -e "${YELLOW}Installing oh-my-zsh...${NC}"
        run_cmd "sh -c \"$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\" "" --unattended"
    fi
}

install_vim_plugins() {
    if [[ ! -d "$HOME/.vim/bundle/Vundle.vim" ]]; then
        echo -e "${YELLOW}Installing Vundle.vim...${NC}"
        run_cmd "git clone https://github.com/gmarik/Vundle.vim.git $HOME/.vim/bundle/Vundle.vim"
    fi
    run_cmd "vim +PluginInstall +qall"
}

install_nvim_plugins() {
    if command -v nvim &>/dev/null || [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}Installing Neovim plugins...${NC}"
        run_cmd "nvim --headless \"+Lazy! sync\" +qa" || true
    fi
}

install_doom_emacs() {
    if [[ ! -d "$HOME/.config/emacs" ]]; then
        echo -e "${YELLOW}Installing Doom Emacs...${NC}"
        run_cmd "git clone --depth 1 https://github.com/doomemacs/doomemacs $HOME/.config/emacs"
        run_cmd "$HOME/.config/emacs/bin/doom install"
    fi
}

install_spacemacs() {
    if [[ ! -d "$HOME/.emacs.d" ]]; then
        echo -e "${YELLOW}Installing Spacemacs...${NC}"
        run_cmd "git clone https://github.com/syl20bnr/spacemacs $HOME/.emacs.d"
    fi
}

install_base16_shell() {
    if [[ ! -d "$HOME/.config/base16-shell" ]]; then
        echo -e "${YELLOW}Installing base16-shell...${NC}"
        run_cmd "git clone https://github.com/chriskempson/base16-shell.git $HOME/.config/base16-shell"
    fi
}

# ============================================================================
# NERD FONTS
# ============================================================================

install_nerd_fonts() {
    local font_dir="$HOME/.local/share/fonts"
    local fonts=("Hack" "FiraCode" "JetBrainsMono" "Meslo")

    run_cmd "mkdir -p $font_dir"

    for font in "${fonts[@]}"; do
        echo -e "${YELLOW}Installing $font Nerd Font...${NC}"
        local url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$font.zip"

        if [[ ! -d "$font_dir/$font" ]] || [[ "$DRY_RUN" == true ]]; then
            local temp_file=$(mktemp)
            run_cmd "curl -fsSL $url -o $temp_file"
            run_cmd "unzip -q $temp_file -d $font_dir/$font"
            run_cmd "rm $temp_file"
        fi
    done

    # Refresh font cache
    if command -v fc-cache &>/dev/null || [[ "$DRY_RUN" == true ]]; then
        run_cmd "fc-cache -f $font_dir"
    fi

    echo -e "${GREEN}Nerd fonts installed successfully${NC}"
}

# ============================================================================
# STOW DEPLOYMENT
# ============================================================================

install_stow() {
    if ! command -v stow &>/dev/null; then
        echo -e "${YELLOW}Installing GNU Stow...${NC}"
        case "$OS" in
            debian)
                sudo_run "$PKG_UPDATE"
                sudo_run "$PKG_INSTALL stow"
                ;;
            arch)
                sudo_run "$PKG_UPDATE"
                sudo_run "$PKG_INSTALL stow"
                ;;
            macos)
                run_cmd "$PKG_INSTALL stow"
                ;;
        esac
    fi
}

deploy_with_stow() {
    local package="$1"
    echo -e "${BLUE}Deploying $package with stow...${NC}"

    run_cmd "cd $SCRIPT_DIR"

    if run_cmd "stow $package -t $HOME" 2>/dev/null || [[ "$DRY_RUN" == true ]]; then
        echo -e "${GREEN}$package deployed successfully${NC}"
    else
        echo -e "${YELLOW}Warning: stow failed for $package${NC}"
        echo "You may need to remove existing files first:"
        echo "  stow $package -D -t ~"
        echo "  stow $package -R -t ~"
    fi
}

# ============================================================================
# INSTALLATION FUNCTIONS
# ============================================================================

install_system_packages() {
    local packages=("$@")
    if [[ ${#packages[@]} -eq 0 ]]; then
        return
    fi

    echo -e "${BLUE}Installing system packages: ${packages[*]}${NC}"
    case "$OS" in
        macos)
            run_cmd "$PKG_UPDATE"
            run_cmd "$PKG_INSTALL ${packages[*]}"
            ;;
        *)
            sudo_run "$PKG_UPDATE"
            sudo_run "$PKG_INSTALL ${packages[*]}"
            ;;
    esac
}

install_language_servers() {
    echo -e "${YELLOW}Installing language servers...${NC}"

    # Python language server
    if command -v pip3 &>/dev/null || [[ "$DRY_RUN" == true ]]; then
        run_cmd "pip3 install --user python-lsp-server" || true
    fi

    # Node.js language servers
    if command -v npm &>/dev/null || [[ "$DRY_RUN" == true ]]; then
        run_cmd "npm install -g typescript-language-server vscode-langservers-extracted" || true
    fi

    # Rust analyzer
    if command -v cargo &>/dev/null || [[ "$DRY_RUN" == true ]]; then
        run_cmd "cargo install rust-analyzer" || true
    fi
}

# ============================================================================
# MAIN INSTALLATION LOGIC
# ============================================================================

install_package() {
    local package="$1"
    local pkg_key="${package}_${OS}"

    # Get package list
    local pkg_list="${PACKAGES[$pkg_key]:-}"

    # Install system packages
    if [[ -n "$pkg_list" ]]; then
        install_system_packages $pkg_list
    fi

    # Install external repositories
    case "$package" in
        tmux)
            install_tmux_plugins
            ;;
        oh-my-zsh)
            install_oh_my_zsh
            ;;
        vim)
            install_vim_plugins
            install_base16_shell
            ;;
        nvim)
            install_nvim_plugins
            install_base16_shell
            ;;
        doom_emacs)
            install_doom_emacs
            ;;
        spacemacs)
            install_spacemacs
            ;;
    esac

    # Deploy with stow
    deploy_with_stow "$package"
}

# ============================================================================
# TUI WITH WHIPTAIL
# ============================================================================

show_package_selection() {
    local packages=(
        "tmux" "Terminal multiplexer with plugin manager" OFF
        "oh-my-zsh" "Zsh configuration framework" OFF
        "vim" "Vim editor with plugins" OFF
        "nvim" "Neovim (kickstart.nvim)" OFF
        "emacs" "GNU Emacs" OFF
        "spacemacs" "Spacemacs distribution" OFF
        "doom_emacs" "Doom Emacs distribution" OFF
        "kitty" "Modern terminal emulator" OFF
        "wezterm" "WezTerm terminal" OFF
        "i3" "i3 window manager" OFF
        "regolith3" "Regolith 3 desktop" OFF
        "w3m" "Text-based web browser" OFF
        "noip" "No-IP DUC" OFF
    )

    # Check if whiptail is available
    if ! command -v whiptail &>/dev/null; then
        echo "Error: whiptail not found. Installing..."
        install_system_packages whiptail
    fi

    local selected_packages
    selected_packages=$(whiptail --title "Dotfiles Deployment" \
        --checklist "Select packages to install (SPACE to select, ENTER to continue):" \
        20 78 13 \
        "${packages[@]}" \
        3>&1 1>&2 2>&3)

    echo "$selected_packages"
}

check_conflicts() {
    local selected=("$@")
    local editors=0
    local emacs_variants=0

    for pkg in "${selected[@]}"; do
        case "$pkg" in
            vim|nvim)
                editors=$((editors + 1))
                ;;
            emacs|spacemacs|doom_emacs)
                emacs_variants=$((emacs_variants + 1))
                ;;
        esac
    done

    if [[ $editors -gt 1 ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            echo -e "${YELLOW}[DRY RUN] Warning: Multiple editors selected${NC}"
        else
            whiptail --title "Conflict Warning" \
                --msgbox "Warning: You've selected multiple editors (vim, nvim).\nOnly one editor is typically needed.\n\nContinuing with all selections." \
                12 78
        fi
    fi

    if [[ $emacs_variants -gt 1 ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            echo -e "${RED}[DRY RUN] Error: Multiple Emacs variants selected${NC}"
            exit 1
        else
            whiptail --title "Conflict Detected" \
                --msgbox "Error: You can only install ONE Emacs variant.\n\nPlease choose between:\n- emacs\n- spacemacs\n- doom_emacs\n\nRun the script again." \
                14 78
            exit 1
        fi
    fi
}

ask_nerd_fonts() {
    local selected=("$@")

    # Check if any editor was selected
    for pkg in "${selected[@]}"; do
        if [[ "$pkg" =~ ^(vim|nvim|emacs|spacemacs|doom_emacs)$ ]]; then
            if [[ "$DRY_RUN" == true ]]; then
                # Auto-accept in dry-run mode
                echo -e "${YELLOW}[DRY RUN] Would install Nerd Fonts (editors selected)${NC}"
                return 0
            fi

            if whiptail --title "Nerd Fonts" \
                --yesno "Would you like to install popular Nerd Fonts?\n\nFonts: Hack, FiraCode, JetBrainsMono, Meslo\n\nThese fonts are required for proper icon display in your editor." \
                12 78; then
                return 0
            else
                return 1
            fi
        fi
    done

    return 1
}

show_summary() {
    local selected=("$@")

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${BOLD}========================================${NC}"
        echo -e "${BOLD}Installation Summary (DRY RUN)${NC}"
        echo -e "${BOLD}========================================${NC}"
        echo "Packages: ${selected[*]}"
        echo ""
        return
    fi

    local mode_text=""
    if [[ "$DRY_RUN" == true ]]; then
        mode_text="\n${BOLD}${YELLOW}DRY RUN MODE${NC} - No actual changes will be made\n"
    fi

    whiptail --title "Installation Summary" \
        --msgbox "The following packages will be installed:\n\n${selected[*]}$mode_text\n\nThis will:\n1. Install system packages\n2. Clone external repositories\n3. Install plugins\n4. Deploy configurations with GNU Stow\n\nPress OK to continue..." \
        20 78
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Dotfiles Interactive Deployment${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo "Detected OS: $OS"
    echo "Package manager: $PKG_MANAGER"

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${BOLD}${YELLOW}DRY RUN MODE${NC} - No actual changes will be made"
    fi

    echo ""

    # Show package selection
    local selected_packages
    if [[ "$DRY_RUN" == true && ${#REQUESTED_PACKAGES[@]} -gt 0 ]]; then
        # In dry-run mode with packages specified as arguments
        selected_packages="${REQUESTED_PACKAGES[*]}"
    elif [[ "$DRY_RUN" == true ]]; then
        # In dry-run mode without packages, show TUI
        selected_packages=$(show_package_selection)
    else
        # Normal interactive mode
        selected_packages=$(show_package_selection)
    fi

    if [[ -z "$selected_packages" ]]; then
        echo "No packages selected. Exiting."
        exit 0
    fi

    # Convert to array
    IFS=' ' read -ra selected_array <<< "$selected_packages"
    for i in "${!selected_array[@]}"; do
        # Remove quotes
        selected_array[$i]="${selected_array[$i]//\"/}"
    done

    # Check for conflicts
    check_conflicts "${selected_array[@]}"

    # Ask about nerd fonts
    if ask_nerd_fonts "${selected_array[@]}"; then
        install_nerd_fonts
    fi

    # Show summary
    show_summary "${selected_array[@]}"

    # Install stow first
    install_stow

    # Install language servers
    install_language_servers

    # Install each package
    for package in "${selected_array[@]}"; do
        echo ""
        echo -e "${BLUE}========================================${NC}"
        echo -e "${BLUE}  Installing: $package${NC}"
        echo -e "${BLUE}========================================${NC}"
        install_package "$package"
    done

    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Installation Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Restart your shell or run: source ~/.zshrc"
    echo "2. For tmux: Press prefix+I to install plugins"
    echo "3. For doom_emacs: Run ~/.config/emacs/bin/doom sync"
    echo ""
    echo "Enjoy your new dotfiles!"
}

main "$@"
