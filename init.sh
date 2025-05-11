sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

ln -s .zshrc ~/.zshrc
ln -s .tmux.conf ~/.tmux.conf
ln -s .alactritty.toml ~/.alactritty.toml
ln -s .config/hypr/ ~/.config/hypr
ln -s .config/nvim/ ~/.config/nvim
