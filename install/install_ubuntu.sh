#! /bin/bash
git clone https://github.com/gmarik/Vundle.vim.git ~/.vim/bundle/Vundle.vim
ln -sf ~/GitHub/dotfiles/tmux/dottmuxdotconf ~/.tmux.conf
ln -sf ~/GitHub/dotfiles/vim/dotvimrc ~/.vimrc

# run vim and install plugins
vim +PluginInstall +q +q

# Download Base16 shell so color is right even in tmux
git clone https://github.com/chriskempson/base16-shell.git ~/.config/base16-shell
