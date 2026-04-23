#!/usr/bin/env bash
# Dotfiles init script - installs dependencies, oh-my-zsh, tpm, and deploys configs
# Usage: ./init.sh

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DOTFILES_DIR"
echo "Dotfiles directory is $DOTFILES_DIR"
echo "Home is $HOME"

ensure_dir() {
    local dir="$1"
    [[ -d "$dir" ]] || mkdir -p "$dir"
}

install_pkg_list() {
    local pkg_file="$1"
    if [[ ! -f "$pkg_file" ]]; then
        echo "Package list not found: $pkg_file"
        return
    fi

    local pkgs
    pkgs="$(grep -v '^#' "$pkg_file" | grep -v '^$' | tr '\n' ' ')"
    if [[ -z "$pkgs" ]]; then
        return
    fi

    echo "Installing packages from $pkg_file: $pkgs"
    if command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y $pkgs
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -Syu --needed $pkgs
    elif command -v apt >/dev/null 2>&1; then
        sudo apt update && sudo apt install -y $pkgs
    elif command -v apk >/dev/null 2>&1; then
        echo "Detected Alpine Linux; install packages manually via apk."
    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y $pkgs
    elif command -v zypper >/dev/null 2>&1; then
        sudo zypper install -y $pkgs
    else
        echo "No supported package manager found. Skipping distro packages."
    fi
}

install_tool() {
    local name="$1" url="$2" dest="$3"
    if [[ -f "$dest" ]]; then
        echo "$name already installed at $dest"
        return
    fi
    echo "Installing $name..."
    curl -sSfL "$url" -o "$dest" || { echo "Failed to download $name"; return; }
    chmod +x "$dest"
    echo "$name installed to $dest"
}

platform="$(uname -s)"

# Ensure ~/.local/bin exists
ensure_dir "$HOME/.local/bin"

# macOS: use Homebrew
if [ "$platform" = "Darwin" ]; then
    if ! command -v brew >/dev/null 2>&1; then
        echo "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    brew bundle install
    echo "Installed Homebrew packages!"
else
    # Linux: detect distro and install package list
    pkg_file="packages.txt"
    if [[ -f "/etc/os-release" ]]; then
        source /etc/os-release
        case "$ID" in
            fedora|rhel|centos|rocky|almalinux) pkg_file="packages-fedora.txt" ;;
            arch|manjaro) pkg_file="packages-arch.txt" ;;
            debian|ubuntu|linuxmint|pop) pkg_file="packages-debian.txt" ;;
            alpine) pkg_file="packages-alpine.txt" ;;
            opensuse*|suse*) pkg_file="packages-opensuse.txt" ;;
            *) pkg_file="packages.txt" ;;
        esac
    fi
    install_pkg_list "$pkg_file"
fi

# Install oh-my-zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" -- --unattended
    echo "Installed Oh My Zsh!"
else
    echo "Oh My Zsh! is already installed. Skipping."
fi

# Install zsh-completions (clones into custom plugins)
if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-completions" ]; then
    git clone https://github.com/zsh-users/zsh-completions "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-completions"
    echo "Installed zsh-completions"
else
    echo "zsh-completions already installed. Skipping."
fi

# Install tpm
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
    echo "Installed Tmux Plugin Manager"
else
    echo "Tmux Plugin Manager is already installed. Skipping."
fi

is_rpm_distro() {
    [[ -f "/etc/os-release" ]] || return 1
    source /etc/os-release
    case "$ID" in
        fedora|rhel|centos|rocky|almalinux) return 0 ;;
        *) return 1 ;;
    esac
}

install_carapace() {
    if command -v carapace >/dev/null 2>&1; then
        echo "carapace already installed. Skipping."
        return
    fi

    if is_rpm_distro; then
        echo "Installing carapace via Gemfury on RPM distro..."
        local repo_file="/etc/yum.repos.d/fury.repo"
        if [[ ! -f "$repo_file" ]]; then
            sudo tee "$repo_file" > /dev/null <<'EOF'
[fury]
name=Gemfury Private Repo
baseurl=https://yum.fury.io/rsteube/
enabled=1
gpgcheck=0
EOF
        fi
        if command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y carapace-bin
        elif command -v yum >/dev/null 2>&1; then
            sudo yum install -y carapace-bin
        fi
    else
        install_tool "carapace" \
            "https://github.com/carapace-sh/carapace-bin/releases/latest/download/carapace-bin-linux-amd64" \
            "$HOME/.local/bin/carapace"
    fi
}

install_carapace

# --- snap-based neovim (Fedora) ---
install_snapd_nvim() {
    # Only on Fedora/RHEL-based distros where snapd is packaged
    if ! is_rpm_distro; then
        return
    fi

    if ! command -v snap >/dev/null 2>&1; then
        echo "snapd binary not found on PATH. Skipping snap nvim setup."
        return
    fi

    # Ensure classic snap confinement symlink exists
    if [[ ! -e /snap ]]; then
        echo "Creating /snap symlink for classic snap confinement..."
        sudo ln -s /var/lib/snapd/snap /snap
    fi

    # Remove Fedora neovim package if installed to avoid PATH conflicts
    if rpm -q neovim &>/dev/null; then
        echo "Removing Fedora neovim package to prefer snap version..."
        sudo dnf remove -y neovim
    fi

    if ! snap list nvim &>/dev/null; then
        echo "Installing nvim via snap (classic)..."
        sudo snap install nvim --classic
    else
        echo "nvim snap already installed. Skipping."
    fi

    # Ensure snap bin dir is available in this session
    if [[ ":$PATH:" != *":/var/lib/snapd/snap/bin:"* ]]; then
        export PATH="${PATH}:/var/lib/snapd/snap/bin"
    fi
}

install_snapd_nvim

# --- jj (Jujutsu version control) ---
install_jj() {
    if command -v jj >/dev/null 2>&1; then
        echo "jj already installed. Skipping."
        return
    fi

    if ! command -v cargo >/dev/null 2>&1; then
        echo "cargo not found. Cannot install jj. Install cargo/rust first."
        return
    fi

    echo "Installing jj via cargo..."
    cargo install --locked --bin jj jj-cli
    echo "jj installed."
}

install_jj

# starship
if ! command -v starship >/dev/null 2>&1; then
    echo "Installing starship..."
    curl -sS https://starship.rs/install.sh | sh -s -- -y
else
    echo "starship already installed. Skipping."
fi

# zoxide
if ! command -v zoxide >/dev/null 2>&1; then
    echo "Installing zoxide..."
    curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
else
    echo "zoxide already installed. Skipping."
fi

# atuin
if ! command -v atuin >/dev/null 2>&1; then
    echo "Installing atuin..."
    curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh
else
    echo "atuin already installed. Skipping."
fi

# Ensure tomlq is available (from python-yq or standalone)
if ! command -v tomlq >/dev/null 2>&1 && ! command -v yq >/dev/null 2>&1; then
    echo "Installing tomlq (python-yq) via pip3..."
    pip3 install --user yq || pip install --user yq || {
        echo "WARNING: pip not found. Install python-yq or yq manually."
    }
else
    echo "tomlq/yq already available. Skipping."
fi

# opencode
if ! command -v opencode >/dev/null 2>&1; then
    echo "Installing opencode..."
    curl -fsSL https://opencode.ai/install | bash
else
    echo "opencode already installed. Skipping."
fi

# Deploy dotfiles
echo "Deploying dotfiles..."
dotter deploy -f

echo "Done! Start a new zsh session: exec zsh"
