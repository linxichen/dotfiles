#! /bin/bash
git clone https://github.com/gmarik/Vundle.vim.git ~/.vim/bundle/Vundle.vim
ln -sf ~/GitHub/dotfiles/tmux/.tmux.conf ~/.tmux.conf
ln -sf ~/GitHub/dotfiles/vim/.vimrc ~/.vimrc

# run vim and install plugins
vim +PluginInstall +q +q
