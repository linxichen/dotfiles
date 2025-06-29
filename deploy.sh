#!/bin/bash
set -euo pipefail  # Exit on error, undefined variables, pipe failures

# Color codes (check if terminal supports colors)
if [[ -t 1 ]] && command -v tput &>/dev/null && tput colors &>/dev/null; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4)
    NC=$(tput sgr0)
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# Global variables with validation
if [[ -z "${HOME:-}" ]]; then
    echo "Error: HOME environment variable is not set" >&2
    exit 1
fi
HOME_DIR="$HOME"

# Validate package name to prevent command injection
validate_package_name() {
    local package="$1"
    if [[ ! "$package" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo -e "${RED}Error: Invalid package name. Only alphanumeric characters, hyphens, and underscores are allowed.${NC}" >&2
        exit 1
    fi
}

# Error handler function
error_handler() {
    local line_no=$1
    echo -e "${RED}Error: Deployment failed on line ${line_no}${NC}" >&2
    exit 1
}

# Print help message
print_help() {
    cat <<EOF
${BLUE}Usage: $0 <package>${NC}
${YELLOW}Available packages:${NC}
  ${GREEN}tmux${NC}       - Deploy tmux configuration with plugin manager
  ${GREEN}oh-my-zsh${NC}  - Deploy oh-my-zsh configuration

${YELLOW}Examples:${NC}
  $0 tmux
  $0 oh-my-zsh

${YELLOW}Note:${NC} This script will install required dependencies automatically
EOF
}

# Detect package manager
detect_package_manager() {
    if command -v apt-get &>/dev/null; then
        echo "apt-get"
    elif command -v yum &>/dev/null; then
        echo "yum"
    elif command -v dnf &>/dev/null; then
        echo "dnf"
    elif command -v pacman &>/dev/null; then
        echo "pacman"
    elif command -v brew &>/dev/null; then
        echo "brew"
    else
        echo "unknown"
    fi
}

# Install stow based on package manager
install_stow() {
    local pkg_manager
    pkg_manager=$(detect_package_manager)
    
    case "$pkg_manager" in
        apt-get)
            sudo apt-get update && sudo apt-get install -y stow
            ;;
        yum|dnf)
            sudo "$pkg_manager" install -y stow
            ;;
        pacman)
            sudo pacman -S --noconfirm stow
            ;;
        brew)
            brew install stow
            ;;
        *)
            echo -e "${RED}Error: Unable to detect package manager. Please install 'stow' manually.${NC}" >&2
            exit 1
            ;;
    esac
}

# Check for required argument
if [[ $# -eq 0 ]] || [[ "$1" = "-h" ]] || [[ "$1" = "--help" ]]; then
    print_help
    exit 0
fi

# Validate package name
validate_package_name "$1"

# Set error trap
trap 'error_handler $LINENO' ERR

# Install stow if not present
if ! command -v stow &>/dev/null; then
    echo -e "${YELLOW}Installing stow...${NC}"
    install_stow
fi

# Ensure dotfiles directory exists and we're in it
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

# Package deployment logic
case "$1" in
    "tmux")
        echo -e "${BLUE}Starting tmux deployment...${NC}"
        
        # Install tmux plugin manager with proper error handling
        TPM_DIR="${HOME_DIR}/.tmux/plugins/tpm"
        if [[ ! -d "$TPM_DIR" ]]; then
            echo -e "${YELLOW}Installing tmux plugin manager...${NC}"
            # Create parent directory if it doesn't exist
            mkdir -p "${HOME_DIR}/.tmux/plugins"
            if git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"; then
                echo -e "${GREEN}tmux plugin manager installed successfully${NC}"
            else
                echo -e "${RED}Failed to clone tmux plugin manager${NC}" >&2
                exit 1
            fi
        else
            echo -e "${GREEN}tmux plugin manager already installed${NC}"
        fi
        
        # Stow tmux configuration
        if stow tmux -t "$HOME_DIR"; then
            echo -e "${GREEN}tmux configuration deployed successfully${NC}"
        else
            echo -e "${RED}Failed to deploy tmux configuration${NC}" >&2
            exit 1
        fi
        
        # Install tmux plugins
        echo -e "${YELLOW}Installing tmux plugins...${NC}"
        TPM_INSTALL_SCRIPT="${TPM_DIR}/bin/install_plugins"
        if [[ -f "$TPM_INSTALL_SCRIPT" ]]; then
            if "$TPM_INSTALL_SCRIPT"; then
                echo -e "${GREEN}tmux plugins installed successfully${NC}"
                echo -e "${YELLOW}Note: Run 'tmux source ~/.tmux.conf' inside a tmux session to reload config${NC}"
            else
                echo -e "${YELLOW}Warning: Plugin installation may have encountered issues${NC}" >&2
            fi
        else
            echo -e "${YELLOW}TPM install script not found. Install plugins manually with prefix+I in tmux${NC}"
        fi
        ;;
        
    "oh-my-zsh")
        echo -e "${BLUE}Starting oh-my-zsh deployment...${NC}"
        
        # Install oh-my-zsh if not present
        if [[ -z "${ZSH:-}" ]] || [[ ! -d "${ZSH:-}" ]]; then
            echo -e "${YELLOW}Installing oh-my-zsh...${NC}"
            echo -e "${YELLOW}Warning: This will download and execute a remote script. Proceed with caution.${NC}"
            
            # Download script first for inspection
            TEMP_SCRIPT=$(mktemp)
            if curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -o "$TEMP_SCRIPT"; then
                # You could add checksum verification here
                sh "$TEMP_SCRIPT"
                rm -f "$TEMP_SCRIPT"
            else
                echo -e "${RED}Failed to download oh-my-zsh installer${NC}" >&2
                rm -f "$TEMP_SCRIPT"
                exit 1
            fi
        fi
        
        # Stow oh-my-zsh configuration
        if stow oh-my-zsh -t "$HOME_DIR"; then
            echo -e "${GREEN}oh-my-zsh configuration deployed successfully${NC}"
        else
            echo -e "${RED}Failed to deploy oh-my-zsh configuration${NC}" >&2
            exit 1
        fi
        ;;
        
    *)
        # Check if the package directory exists before attempting to stow
        if [[ ! -d "$1" ]]; then
            echo -e "${RED}Error: Package directory '$1' not found${NC}" >&2
            exit 1
        fi
        
        echo -e "${BLUE}Starting $1 deployment...${NC}"
        if stow "$1" -t "$HOME_DIR"; then
            echo -e "${GREEN}$1 configuration deployed successfully${NC}"
        else
            echo -e "${RED}Failed to deploy $1 configuration${NC}" >&2
            exit 1
        fi
        ;;
esac

echo -e "${GREEN}Deployment completed successfully${NC}"
exit 0