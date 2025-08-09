DOTFILES_DIR="$(dirname "$0")"
cd $DOTFILES_DIR
echo "Dotfiles directory is $DOTFILES_DIR"
echo "Home is $HOME"

platform="$(uname -s)"

if [ platform == "Darwin" ]; then
  if [ ! -f $(command -v brew) ]; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  brew bundle install
  echo "Installed Homebrew packages!"
else
  if [ -f $(command -v pacman) ]; then
    sudo pacman -Syu --needed $(cat packages.txt)
  elif [ -f $(command -v apt) ]; then
    sudo apt update && sudo apt install -y $(cat packages.txt)
    echo "Installed Linux packages!"
  elif [ -f $(command -v apk) ]; then
    echo "Detected Alpine Linux; packages should already be installed."
  elif [ -f $(command -v dnf) ]; then
    sudo dnf install -y $(cat packages.txt)
    echo "Installed Fedora packages!"
  elif [ -f $(command -v yum) ]; then
    sudo yum install -y $(cat packages.txt)
    echo "Installed CentOS/RHEL packages!"
  elif [ -f $(command -v zypper) ]; then
    sudo zypper install -y $(cat packages.txt)
    echo "Installed openSUSE packages!"
  else
    echo "Unsupported $Linux distro"
    cat /etc/os-release
    exit 1
  fi
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
  if [[ "$file" != "." && "$file" != ".." && "$file" != ".git" && "$file" ]]; then
    echo "Processing $file"
    target="$HOME/$file"
    echo "Target is $target"
    if [ -e "$target" ]; then
      mv $target "$target.$(date +%s).bak"
    fi
    source="$DOTFILES_DIR/$file"
    ln -s "$source" "$target"
    echo "Linked $source to $target"
  fi
done
