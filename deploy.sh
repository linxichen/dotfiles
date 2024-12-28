#!/bin/bash

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global variables
HOME_DIR=$HOME

# Error handler function
error_handler() {
  echo -e "${RED}Error: Deployment failed on line $1${NC}"
  exit 1
}

# Print help message
print_help() {
  echo -e "${BLUE}Usage: $0 <package>${NC}"
  echo -e "${YELLOW}Available packages:${NC}"
  echo -e "  ${GREEN}tmux${NC}       - Deploy tmux configuration with plugin manager"
  echo -e "  ${GREEN}oh-my-zsh${NC}  - Deploy oh-my-zsh configuration"
  echo -e "\n${YELLOW}Examples:${NC}"
  echo -e "  $0 tmux"
  echo -e "  $0 oh-my-zsh"
  echo -e "\n${YELLOW}Note:${NC} This script will install required dependencies automatically"
}

# Check for required argument
if [ -z "$1" ] || [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
  print_help
  exit 0
fi

# Set error trap
trap 'error_handler $LINENO' ERR

# Install stow if not present
if ! command -v stow &>/dev/null; then
  echo -e "${YELLOW}Installing stow...${NC}"
  sudo apt-get install -y stow
fi

# Package deployment logic
case "$1" in
"tmux")
  echo -e "${BLUE}Starting tmux deployment...${NC}"

  # Install tmux plugin manager
  if [ ! -d "$HOME_DIR/.tmux/plugins/tpm" ]; then
    echo -e "${YELLOW}Installing tmux plugin manager...${NC}"
    git clone https://github.com/tmux-plugins/tpm "$HOME_DIR/.tmux/plugins/tpm"
  else
    echo -e "${GREEN}tmux plugin manager already installed${NC}"
  fi

  # Stow tmux configuration
  stow tmux -t "$HOME_DIR"
  echo -e "${GREEN}tmux configuration deployed successfully${NC}"
  ;;

"oh-my-zsh")
  echo -e "${BLUE}Starting oh-my-zsh deployment...${NC}"

  # Install oh-my-zsh if not present
  if [ -z "$ZSH" ]; then
    echo -e "${YELLOW}Installing oh-my-zsh...${NC}"
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  fi

  # Stow oh-my-zsh configuration
  stow oh-my-zsh -t "$HOME_DIR"
  echo -e "${GREEN}oh-my-zsh configuration deployed successfully${NC}"
  ;;

*)
  echo -e "${BLUE}Starting $1 deployment...${NC}"
  stow "$1" -t "$HOME_DIR"
  echo -e "${GREEN}$1 configuration deployed successfully${NC}"
  ;;
esac

echo -e "${GREEN}Deployment completed successfully${NC}"
exit 0
