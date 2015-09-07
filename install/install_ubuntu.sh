#! /bin/bash
# Install cuda and add ld path
wget http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1404/x86_64/cuda-repo-ubuntu1404_7.0-28_amd64.deb -P ~/Downloads/
sudo dpkg -i ~/Downloads/cuda-repo-ubuntu1404_7.0-28_amd64.deb
sudo apt-get install cuda
echo " echo '/usr/local/cuda-7.0/lib64' >> /etc/ld.so.conf.d/newtmux2.conf " | sudo sh
sudo ldconfig

# Firstly update apt-get repo
sudo apt-get update

# Install core stuff like vim automake and ncurses
sudo apt-get install vim vim-doc automake libncurses-dev git

# install libevent 2.0
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
sudo make install

# need to update ldpath so tmux can find libevent
echo " echo '/usr/local/bin' >> /etc/ld.so.conf.d/newtmux2.conf " | sudo sh

# customize tmux and vim
git clone https://github.com/gmarik/Vundle.vim.git ~/.vim/bundle/Vundle.vim
ln -sf ~/GitHub/dotfiles/tmux/dottmuxdotconf ~/.tmux.conf
ln -sf ~/GitHub/dotfiles/vim/dotvimrc ~/.vimrc

# run vim and install plugins
vim +PluginInstall +q +q

# Download Base16 shell so color is right even in tmux
git clone https://github.com/chriskempson/base16-shell.git ~/.config/base16-shell
echo '# Base16 Shell' >> ~/.bashrc
echo 'BASE16_SHELL="$HOME/.config/base16-shell/base16-default.dark.sh"' >> ~/.bashrc
echo '[[ -s $BASE16_SHELL ]] && source $BASE16_SHELL' >> ~/.bashrc
echo 'export TERM=xterm-256color' >> ~/.bashrc

# Download powerline fonts
git clone https://github.com/powerline/fonts.git
cd fonts
sudo ./install

# Cp all scripts to /etc/profile.d
sudo cp ~/GitHub/dotfiles/ubuntu_profile_d/*.sh /etc/profile.d/

# Finally run ldconfig for CUDA
