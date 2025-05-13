if command -v brew &> dev/null; then
  brew bundle install
  echo "Installed Homebrew packages"
fi

if [ ! -d ~/.oh-my-zsh ]; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  echo "Installed Oh My Zsh!"
fi

if [ ! -d ~/.tmux/plugins/tpm ]; then
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
  echo "Installed Tmux Plugin Manager"
fi

if [ ! -f ~/.alacritty.toml ]; then
  ln -s .alactritty.toml ~/.alactritty.toml
  echo "Linked Alacritty config"
fi

if [ ! -f ~/.zshrc ]; then
  ln -s .zshrc ~/.zshrc
  echo "Linked Zsh config"
fi

if [ ! -f .tmux.conf ]; then
  ln -s .tmux.conf ~/.tmux.conf
  echo "Linked Tmux config"
fi

if [ ! -d ~/.config ]; then
  mkdir ~/.config
  echo "Created ~/.config directory"
fi

if [ ! -d ~/.config/hypr ]; then
  ln -s .config/hypr/ ~/.config/hypr
  echo "Linked Hyprland config"
fi

if [ ! -d ~/.config/nvim ]; then
  ln -s .config/nvim/ ~/.config/nvim
  echo "Linked Neovim config"
fi
