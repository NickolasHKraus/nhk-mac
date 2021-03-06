#!/usr/bin/env bash
#
# Functions
#
# This file is sourced by `run.sh`.

function echo_c {
  echo -en "${2}"
  echo "${1}"
  echo -en "${RESET}"
}

function usage {
  echo_c
  echo_c "Usage: nhk-mac" "${WHITE}"
  echo_c
}

function set_hostname {
  echo_c "Setting hostname..." "${WHITE}"
  if [ -z $HOSTNAME ]; then
    echo_c "Error: Provide HOSTNAME in \`var.sh\`." "${RED}"
    exit 1
  fi
  sudo scutil --set HostName "${HOSTNAME}"
}

function set_wallpaper {
  echo_c "Setting wallpaper..." "${WHITE}"
  db="$HOME/Library/Application Support/Dock/desktoppicture.db"
  val_0=0
  val_1=1
  val_2=0.0841198042035103
  val_3=0.084135964512825
  val_4=0.0841171219944954
  val_5="'$(sudo find /System/Library -type d -name "*Solid Colors" 2>/dev/null)'"
  val_6="'$(sudo find /System/Library -type f -name "*Transparent.tiff" 2>/dev/null)'"
  sqlite3 "$db" "DELETE FROM data;"
  sqlite3 "$db" "INSERT INTO data(value) VALUES ($val_5), ($val_0), ($val_1), ($val_6), ($val_2), ($val_3), ($val_4);" && \
  killall Dock
}

function configure_macos {
  echo_c "Configuring macOS..." $WHITE
  defaults write -g ApplePressAndHoldEnabled -bool false
  defaults write -g InitialKeyRepeat -int 15
  defaults write -g KeyRepeat -int 1
}

function configure_dock {
  echo_c "Configuring Dock..." "${WHITE}"
  defaults write com.apple.dock autohide -bool true
  defaults write com.apple.dock autohide-delay -int 0
  defaults write com.apple.dock autohide-time-modifier -int 0
  defaults write com.apple.dock persistent-apps -array
  defaults write com.apple.dock persistent-others -array
  defaults write com.apple.dock recent-apps -array
  defaults write com.apple.dock show-recent -bool false
  defaults write com.apple.dock tilesize -int 32
  defaults write com.apple.dock 'orientation' -string 'left'
  killall Dock
}

function install_xcode {
  if [ ! -x "$(command -v git)" ]; then
    echo_c "Installing Xcode Developer Tools..." "${WHITE}"
    xcode-select --install
    echo_c "Press ENTER to continue."
    read -n 1
  fi
}

function install_homebrew {
  if [ ! -x "$(command -v brew)" ]; then
    echo_c "Installing Homebrew..." "${WHITE}"
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
  echo_c "Updating Homebrew..." "${WHITE}"
  brew update
  fi
}

function install_homebrew_bundle {
  echo_c "Installing Homebrew Bundle..." "${WHITE}"
  brew bundle
}

function install_iterm2 {
  if [ ! -d /Applications/iTerm.app ]; then
    echo_c "Installing iTerm2..." "${WHITE}"
    ITERM2_VERSION=$(echo $ITERM2_VERSION | sed 's/\./_/g')
    curl -LOk https://iterm2.com/downloads/stable/iTerm2-$ITERM2_VERSION.zip
    unzip -q iTerm2-$ITERM2_VERSION.zip
    mv iTerm.app /Applications
    rm iTerm2-$ITERM2_VERSION.zip
  fi
}

function install_spectacle {
  if [ ! -d /Applications/Spectacle.app ]; then
    echo_c "Installing Spectacle..." "${WHITE}"
    curl -LOk https://s3.amazonaws.com/spectacle/downloads/Spectacle+$SPECTACLE_VERSION.zip
    unzip -q Spectacle+$SPECTACLE_VERSION.zip
    mv Spectacle.app /Applications
    rm Spectacle+$SPECTACLE_VERSION.zip
  fi
}

function install_zsh {
  if [ ! -d $HOME/.oh-my-zsh ]; then
    echo_c "Installing Zsh..." "${WHITE}"
    git clone https://github.com/NickolasHKraus/oh-my-zsh $HOME/.oh-my-zsh
    cd $HOME/.oh-my-zsh
    git remote add upstream git@github.com:robbyrussell/oh-my-zsh.git
    git remote remove origin
    git remote add origin git@github.com:NickolasHKraus/oh-my-zsh.git
    cd $HOME
  fi
}

function install_vundle {
  if [ ! -d $HOME/.vim/bundle/Vundle.vim ]; then
    echo_c "Installing Vundle..." "${WHITE}"
    git clone https://github.com/VundleVim/Vundle.vim.git $HOME/.vim/bundle/Vundle.vim
  fi
}

function install_powerline_fonts {
  if [ ! "$(ls $HOME/Library/Fonts)" ]; then
    echo_c "Installing Powerline fonts..." "${WHITE}"
    git clone https://github.com/powerline/fonts.git --depth=1
    cd fonts
    ./install.sh
    cd ..
    rm -rf fonts
  fi
}

function create_ssh_keys {
  echo_c "Creating SSH keys..." "${WHITE}"
  mkdir -p $HOME/.ssh
  if [ ! -f $HOME/.ssh/id_rsa ]; then
    ssh-keygen -b 2048 -t rsa -f $HOME/.ssh/id_rsa -P ""
    chmod 400 $HOME/.ssh/id_rsa
  else
    echo_c "SSH keys already exist." $GREEN
  fi
  echo_c "Add your public key to GitHub, GitLab, or Bitbucket." $YELLOW
  cat $HOME/.ssh/id_rsa.pub
  echo_c "Press ENTER to continue."
  read -n 1
}

function setup_workspace {
  echo_c "Setting up workspace..." "${WHITE}"
  if [ ! -d $HOME/NickolasHKraus ]; then
    echo_c "Creating 'NickolasHKraus' directory..." "${WHITE}"
    mkdir -p $HOME/NickolasHKraus
  else
    echo_c "${HOME}/NickolasHKraus already exists." $GREEN
  fi
  echo_c "Cloning repositories..." "${WHITE}"
  cd $HOME/NickolasHKraus
  if ! [ -x "$(command -v jq)" ]; then
    brew install jq
  fi
  (ssh-agent -s && ssh-add ~/.ssh/id_rsa) >/dev/null 2>&1
  ssh git@github.com >/dev/null 2>&1
  if [ $? -eq 255 ]; then
    echo_c "Permission denied (publickey)." $RED
    exit 1
  fi

  # The GitHub API only returns 30 results. Therefore, increment PAGE until no
  # results are returned.
  PAGE=1
  SSH_URLS=()
  while true; do
    urls=($(curl -s "https://api.github.com/users/NickolasHKraus/repos?sort=full_name&page=$PAGE" | jq '.[].ssh_url' | tr -d \"))
    if [ ${#urls[@]} -eq 0 ]; then
      break
    else
      SSH_URLS+=(${urls[@]})
    fi
    let PAGE=PAGE+1
  done

  for ssh_url in "${SSH_URLS[@]}"; do
    echo Cloning "${ssh_url}"..
    output=$(git clone "${ssh_url}" 2>&1)
    if [ $(echo $output | grep -i "already exists" -c) -ne 0 ]; then
      echo_c "Repository already exists." $GREEN
    fi
  done
}

function install_homebrew_packages {
  echo_c "Installing Homebrew packages..." "${WHITE}"
  brew bundle --file=$HOME/NickolasHKraus/dotfiles/Brewfile
  echo_c "Upgrading Homebrew packages..." "${WHITE}"
  brew upgrade
}

function configure_python {
  echo_c "Configuring virtualenv and virtualenvwrapper..." $WHITE
  export WORKON_HOME=$HOME/.virtualenvs
  export VIRTUALENVWRAPPER_PYTHON=$HOME/.pyenv/shims/python
  export VIRTUALENVWRAPPER_VIRTUALENV=$HOME/.pyenv/shims/virtualenv
  # '--enable-framework' option is required by YouCompleteMe
  export PYTHON_CONFIGURE_OPTS="--enable-framework"
  echo_c "Installing Python ${PYTHON2_VERSION} via pyenv..." $WHITE
  pyenv install $PYTHON2_VERSION
  echo_c "Installing Python ${PYTHON3_VERSION} via pyenv..." $WHITE
  pyenv install $PYTHON3_VERSION
  echo_c "Creating virtual environments..." $WHITE
  eval "$(pyenv init -)"
  pyenv shell $PYTHON2_VERSION
  echo_c "Installing virtualenv and virtualenvwrapper..." $WHITE
  pip install virtualenv virtualenvwrapper
  pyenv virtualenvwrapper
  mkvirtualenv dev2
  deactivate
  pyenv shell $PYTHON3_VERSION
  echo_c "Installing virtualenv and virtualenvwrapper..." $WHITE
  pip install virtualenv virtualenvwrapper
  pyenv virtualenvwrapper
  mkvirtualenv dev3
}

function install_python_packages {
  echo_c "Installing Python packages..." "${WHITE}"
  workon dev3
  pip install -r $HOME/NickolasHKraus/dotfiles/requirements.txt
}

function install_bash_scripts {
  echo_c "Installing bash-scripts..." "${WHITE}"
  cd $HOME/NickolasHKraus/bash-scripts
  source install.sh
}

function install_dotfile {
  echo_c "Installing dotfiles..." "${WHITE}"
  cd $HOME/NickolasHKraus/dotfiles
  source install.sh
}

function install_vim_scripts {
  echo_c "Installing vim-scripts..." "${WHITE}"
  cd $HOME/NickolasHKraus/vim-scripts
  source install.sh
}

function install_vim_plugins {
  echo_c "Installing Vim plugins..." "${WHITE}"
  vim +PluginInstall +qall
}

function install_fzf {
  echo_c "Installing fzf..." "${WHITE}"
  if [ ! -f $HOME/.fzf.zsh ]; then
    $(brew --prefix)/opt/fzf/install
  fi
}

function install_ycm {
  echo_c "Installing YouCompleteMe..." "${WHITE}"
  cd $HOME/.vim/bundle/YouCompleteMe
  ./install.py --clang-completer --go-completer
}
