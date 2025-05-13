if [ "$(uname)" == "Darwin" ]; then
  if [ ! -f $(command -v brew) ]; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  brew bundle install
  echo "Installed Homebrew packages!"
fi

if [ ! -d ~/.oh-my-zsh ]; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  echo "Installed Oh My Zsh!"
else
  echo "Oh My Zsh! is already installed. Skipping."
fi

if [ ! -d ~/.tmux/plugins/tpm ]; then
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
  echo "Installed Tmux Plugin Manager"
else
  echo "Tmux Plugin Manager is already installed. Skipping."
fi

for file in .*; do
  if [[ "$file" != "." && "$file" != ".." && "$file" != ".git" ]]; then
    target="$HOME/$file"
    if [ ! -e "$target" ]; then
      ln -s "$PWD/$file" "$target"
      echo "Linked $file to $target"
    else
      echo "$target is already linked. Skipping."
    fi
  fi
done
