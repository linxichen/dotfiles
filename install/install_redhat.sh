#! /bin/bash
# install libevent 2.0
cd /tmp
wget https://sourceforge.net/projects/levent/files/libevent/libevent-2.0/libevent-2.0.22-stable.tar.gz
tar -xvzf libevent-2.0.22-stable.tar.gz
cd libevent-2.0.22-stable
./configure
make
sudo make install

# update tmux first?
git clone https://github.com/tmux/tmux.git
cd tmux
sh autogen.sh
./configure && make

# need to update ldpath so tmux can find libevent
echo " echo '/usr/local/bin' >> /etc/ld.so.conf.d/newtmux2.conf " | sudo sh

git clone https://github.com/gmarik/Vundle.vim.git ~/.vim/bundle/Vundle.vim
ln -sf ~/GitHub/dotfiles/tmux/dottmuxdotconf ~/.tmux.conf
ln -sf ~/GitHub/dotfiles/vim/dotvimrc_k40 ~/.vimrc

# run vim and install plugins
vim +PluginInstall +q +q

# Download Base16 shell so color is right even in tmux
git clone https://github.com/chriskempson/base16-shell.git ~/.config/base16-shell
