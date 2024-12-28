#!/bin/bash

# Global variables
HOME_DIR=$HOME

# Error handler function
error_handler() {
    echo "Error: Deployment failed on line $1"
    exit 1
}

# Check for required argument
if [ -z "$1" ]; then
    echo "Usage: $0 <package>"
    echo "Available packages: tmux, oh-my-zsh"
    exit 1
fi

# Set error trap
trap 'error_handler $LINENO' ERR

# Install stow if not present
if ! command -v stow &> /dev/null; then
    echo "Installing stow..."
    sudo apt-get install -y stow
fi

# Package deployment logic
case "$1" in
    "tmux")
        echo "Starting tmux deployment..."
        
        # Install tmux plugin manager
        if [ ! -d "$HOME_DIR/.tmux/plugins/tpm" ]; then
            echo "Installing tmux plugin manager..."
            git clone https://github.com/tmux-plugins/tpm "$HOME_DIR/.tmux/plugins/tpm"
        else
            echo "tmux plugin manager already installed"
        fi
        
        # Stow tmux configuration
        stow tmux -t "$HOME_DIR"
        ;;
        
    "oh-my-zsh")
        echo "Starting oh-my-zsh deployment..."
        
        # Install oh-my-zsh if not present
        if [ -z "$ZSH" ]; then
            echo "Installing oh-my-zsh..."
            sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
        fi
        
        # Stow oh-my-zsh configuration
        stow oh-my-zsh -t "$HOME_DIR"
        ;;
        
    *)
        echo "Starting $1 deployment..."
        stow "$1" -t "$HOME_DIR"
        ;;
esac

echo "Deployment completed successfully"
exit 0

