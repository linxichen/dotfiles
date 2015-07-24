#! /bin/bash
echo "installing homebrew..."
ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

# Download powerline fonts but use them in vim-airline
echo "installing powerline fonts..."
git clone https://github.com/powerline/fonts.git
cd fonts
./install.sh
cd ..
rm -rf fonts

echo "installing vundle ..."
git clone https://github.com/gmarik/Vundle.vim.git ~/.vim/bundle/Vundle.vim

echo "linking dot files ..."
ln -sf ~/GitHub/dotfiles/tmux/.tmux.conf ~/.tmux.conf
ln -sf ~/GitHub/dotfiles/vim/.vimrc ~/.vimrc
ln -sf ~/GitHub/dotfiles/macprofile/.profile ~/.profile

echo "install and activate vim plugins ..."
vim +PluginInstall +q +q

