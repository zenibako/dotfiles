DOTFILES_DIR="$(dirname "$0")"
cd $DOTFILES_DIR
echo "Dotfiles directory is $DOTFILES_DIR"
echo "Home is $HOME"

platform="$(uname -s)"

if [ "$platform" = "Darwin" ]; then
  if ! command -v brew >/dev/null 2>&1; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  brew bundle install
  echo "Installed Homebrew packages!"
else
  if command -v pacman >/dev/null 2>&1; then
    sudo pacman -Syu --needed $(cat packages.txt)
  elif command -v apt >/dev/null 2>&1; then
    sudo apt update && sudo apt install -y $(cat packages.txt)
    echo "Installed Linux packages!"
  elif command -v apk >/dev/null 2>&1; then
    echo "Detected Alpine Linux; packages should already be installed."
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y $(cat packages.txt)
    echo "Installed Fedora packages!"
  elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y $(cat packages.txt)
    echo "Installed CentOS/RHEL packages!"
  elif command -v zypper >/dev/null 2>&1; then
    sudo zypper install -y $(cat packages.txt)
    echo "Installed openSUSE packages!"
  else
    echo "Unsupported Linux distro"
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

dotter deploy -f
