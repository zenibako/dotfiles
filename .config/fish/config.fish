if status is-interactive
    # Commands to run in interactive sessions can go here
end
set -gx EDITOR nvim
starship init fish | source
fish_vi_key_bindings
carapace-spec $HOME/.config/oclif-carapace-spec/sf.yml | source

zoxide init fish | source
