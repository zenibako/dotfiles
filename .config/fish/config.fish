if status is-interactive
    # Commands to run in interactive sessions can go here
end
set -gx EDITOR nvim
starship init fish | source
fish_vi_key_bindings
carapace-spec $HOME/.config/oclif-carapace-spec/sf.yml | source

zoxide init fish | source

# Created by `pipx` on 2025-08-07 19:05:08
set PATH $PATH /Users/chandler.anderson/.local/bin
