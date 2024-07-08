#!/bin/bash

# Check if an argument is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <package>"
  exit 1
fi

# Function to handle errors
error_handler() {
    echo "An error occurred on line $1"
    exit 1
}

# Set trap to catch errors and call the error handler
trap 'error_handler $LINENO' ERR

HOME_DIR=$HOME

# execute code per case
case "$1" in
  "tmux")
    echo "Starting the tmux deployment..."
    sudo apt install stow
    if [ ! -d "$HOME/.tmux/plugins/tpm" ] ; then
      git clone https://github.com/tmux-plugins/tpm $HOME/.tmux/plugins/tpm
    else
      echo "Found existing tpm"
    fi
    stow tmux -t $HOME
    echo "Done."
    ;;
  "oh-my-zsh")
    echo "Starting the oh-my-zsh deployment..."
    if [ -z "$ZSH" ]; then
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    fi
    stow oh-my-zsh -t $HOME
    echo "Done."
    ;;
  *)
    echo "Starting the $1 deployment..."
    sudo apt install stow
    stow "$1" -t $HOME
    ;;
esac

exit 0

