#! /bin/bash
ln -sf ~/GitHub/dotfiles/tmux/.tmux.conf ~/.tmux.conf
ln -sf ~/GitHub/dotfiles/vim/.vimrc ~/.vimrc

# Download powerline fonts but use them in vim-airline
echo "installing powerline fonts..."
git clone https://github.com/powerline/fonts.git
cd fonts
./install.sh
cd ..
rm -rf fonts

# run vim and install plugins
vim +PluginInstall +q +q
