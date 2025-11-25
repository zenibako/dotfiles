# config.nu
#
# Installed by:
# version = "0.106.1"
#
# This file is used to override default Nushell settings, define
# (or import) custom commands, or run any other startup tasks.
# See https://www.nushell.sh/book/configuration.html
#
# Nushell sets "sensible defaults" for most configuration settings, 
# so your `config.nu` only needs to override these defaults if desired.
#
# You can open this file in your default editor using:
#     config nu
#
# You can also pretty-print and page through the documentation for configuration
# options using:
#     config nu --doc | nu-highlight | less -R

$env.config.buffer_editor = "nvim"
$env.config.edit_mode = "vi"
$env.config.cursor_shape.vi_insert = "line"       # Cursor shape in vi-insert mode
$env.config.cursor_shape.vi_normal = "block"  # Cursor shape in normal vi mode

$env.config.show_banner = false

mkdir ($nu.data-dir | path join "vendor/autoload")
starship init nu | save -f ($nu.data-dir | path join "vendor/autoload/starship.nu")

$env.STARSHIP_SHELL = "nu"

def create_left_prompt [] {
    starship prompt --cmd-duration $env.CMD_DURATION_MS $'--status=($env.LAST_EXIT_CODE)'
}

# Use nushell functions to define your right and left prompt
$env.PROMPT_COMMAND = { || create_left_prompt }
$env.PROMPT_COMMAND_RIGHT = ""

# The prompt indicators are environmental variables that represent
# the state of the prompt
$env.PROMPT_INDICATOR = ""
$env.PROMPT_INDICATOR_VI_INSERT = ""
$env.PROMPT_INDICATOR_VI_NORMAL = ""
$env.PROMPT_MULTILINE_INDICATOR = "::: "

source ~/.local/share/atuin/init.nu

atuin gen-completions --shell nushell | save -f "~/.cache/atuin.nu"
source ~/.cache/atuin.nu

source ~/.zoxide.nu

carapace _carapace nushell | save -f "~/.cache/carapace/init.nu"
source ~/.cache/carapace/init.nu

source ~/.local/share/atuin/init.nu

def "nu-complete zoxide path" [context: string] {
    let parts = $context | split row " " | skip 1
    {
      options: {
        sort: false,
        completion_algorithm: substring,
        case_sensitive: false,
      },
      completions: (^zoxide query --list --exclude $env.PWD -- ...$parts | lines),
    }
  }

def --env --wrapped z [...rest: string@"nu-complete zoxide path"] {
  __zoxide_z ...$rest
}


# Workmux completions
def "nu-complete workmux subcommands" [] {
    [
        { value: "add", description: "Create a new worktree and tmux window" }
        { value: "open", description: "Open a tmux window for an existing worktree" }
        { value: "merge", description: "Merge a branch, then clean up the worktree and tmux window" }
        { value: "remove", description: "Remove a worktree, tmux window, and branch without merging" }
        { value: "rm", description: "Remove a worktree, tmux window, and branch without merging" }
        { value: "list", description: "List all worktrees" }
        { value: "ls", description: "List all worktrees" }
        { value: "init", description: "Generate example .workmux.yaml configuration file" }
        { value: "claude", description: "Claude Code integration commands" }
        { value: "completions", description: "Generate shell completions" }
        { value: "help", description: "Print help message" }
    ]
}

def "nu-complete workmux branches" [] {
    let worktree_branches = (do { git worktree list --porcelain } | complete)
    if $worktree_branches.exit_code == 0 {
        $worktree_branches.stdout
        | lines
        | where ($it | str starts-with "branch refs/heads/")
        | each { |line| $line | str replace "branch refs/heads/" "" }
    } else {
        []
    }
}

def "nu-complete workmux git-branches" [] {
    let branches = (do { git branch --format="%(refname:short)" } | complete)
    if $branches.exit_code == 0 {
        $branches.stdout | lines
    } else {
        []
    }
}

def "nu-complete workmux shells" [] {
    ["bash", "elvish", "fish", "powershell", "zsh"]
}

def "nu-complete workmux claude-subcommands" [] {
    [
        { value: "prune", description: "Remove stale entries from ~/.claude.json" }
        { value: "help", description: "Print help for subcommand" }
    ]
}

export extern "workmux" [
    command?: string@"nu-complete workmux subcommands"
    --help(-h)
    --version(-V)
]

export extern "workmux add" [
    branch_name?: string@"nu-complete workmux git-branches"
    --pr: int
    --base: string
    --prompt(-p): string
    --prompt-file(-P): path
    --prompt-editor(-e)
    --no-hooks(-H)
    --no-file-ops(-F)
    --no-pane-cmds(-C)
    --background(-b)
    --with-changes(-w)
    --patch
    --include-untracked(-u)
    --agent(-a): string
    --count(-n): int
    --foreach: string
    --branch-template: string
    --help(-h)
]

export extern "workmux open" [
    branch_name: string@"nu-complete workmux branches"
    --run-hooks
    --force-files
    --help(-h)
]

export extern "workmux merge" [
    branch_name?: string@"nu-complete workmux branches"
    --ignore-uncommitted
    --delete-remote(-r)
    --rebase
    --squash
    --keep(-k)
    --help(-h)
]

export extern "workmux remove" [
    branch_name?: string@"nu-complete workmux branches"
    --force(-f)
    --delete-remote(-r)
    --keep-branch(-k)
    --help(-h)
]

export extern "workmux rm" [
    branch_name?: string@"nu-complete workmux branches"
    --force(-f)
    --delete-remote(-r)
    --keep-branch(-k)
    --help(-h)
]

export extern "workmux list" [
    --help(-h)
]

export extern "workmux ls" [
    --help(-h)
]

export extern "workmux init" [
    --help(-h)
]

export extern "workmux completions" [
    shell: string@"nu-complete workmux shells"
    --help(-h)
]

export extern "workmux claude" [
    command?: string@"nu-complete workmux claude-subcommands"
    --help(-h)
]

export extern "workmux claude prune" [
    --help(-h)
]

export extern "workmux help" [
    command?: string@"nu-complete workmux subcommands"
]

# Custom nvm wrapper
def --env --wrapped nvm [...args] {
    let nvm_sh = "/opt/homebrew/opt/nvm/nvm.sh"

    if ($args | is-empty) {
        bash -c $"source ($nvm_sh); nvm"
        return
    }

    let cmd = $"nvm ($args | str join ' ')"
    let delimiter = "---NVM_ENV_JSON---"

    let res = (bash -c $"export NVM_DIR='($env.NVM_DIR)'; source ($nvm_sh); ($cmd); echo ($delimiter); jq -n --arg nvm_bin \"\$NVM_BIN\" --arg nvm_inc \"\$NVM_INC\" --arg path \"\$PATH\" '{NVM_BIN: \$nvm_bin, NVM_INC: \$nvm_inc, PATH: \$path}'" | complete)

    if $res.exit_code != 0 {
        print $res.stderr
        return
    }

    let parts = ($res.stdout | split row $delimiter)
    print ($parts | first | str trim)

    if ($parts | length) > 1 {
        let new_env = ($parts | last | from json)

        load-env {
            NVM_BIN: $new_env.NVM_BIN
            NVM_INC: $new_env.NVM_INC
        }
        $env.PATH = ($new_env.PATH | split row (char esep))
    }
}
