#! /bin/bash
git clone https://github.com/gmarik/Vundle.vim.git ~/.vim/bundle/Vundle.vim
ln -sf ~/GitHub/dotfiles/tmux/dottmuxdotconf ~/.tmux.conf
ln -sf ~/GitHub/dotfiles/vim/dotvimrc ~/.vimrc

# run vim and install plugins
vim +PluginInstall +q +q

