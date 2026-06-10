import _shared

# ── Starship format strings (built outside schema body to avoid $-interpolation) ──
_dollar = "$"
_brace_open = "{"
_brace_close = "}"
# Note: original starship.toml had format as a single line with escaped newlines.
# We concatenate without separators to match the original behavior.
_starship_format = _dollar + "username" + _dollar + "hostname" + _dollar + "localip" + _dollar + "shlvl" + _dollar + "singularity" + _dollar + "kubernetes" + _dollar + "directory" + _dollar + "vcsh" + _dollar + "fossil_branch" + _dollar + "fossil_metrics" + _dollar + "git_branch" + _dollar + "git_commit" + _dollar + "git_state" + _dollar + "git_metrics" + _dollar + "git_status" + _dollar + _brace_open + "custom.jj_change" + _brace_close + _dollar + _brace_open + "custom.jj_empty" + _brace_close + _dollar + _brace_open + "custom.jj_desc" + _brace_close + _dollar + "all"

_starship_right = _dollar + "shell"

# ── Starship config ──────────────────────────────────────────────────
starship = _shared.StarshipConfig {
    add_newline = True
    format = _starship_format
    right_format = _starship_right
    command_timeout = 750
    package = {
        disabled = True
    }
    git_commit = {
        disabled = True
    }
    custom = {
        sf = {
            description = "The target org used by default for Salesforce CLI commands"
            command = "sf config get target-org --json | from json | get result.value.0"
            when = "sf config get target-org --json | from json | get result.value"
            format = "via [$symbol ($output)]($style) "
            style = "bold 039"
            symbol = "󰢎"
        }
        jj_change = {
            description = "The working copy of the repo in your current directory"
            command = "jj log --no-graph -r=@ -T='separate(\" \", working_copies, change_id.shortest(), bookmarks,)'"
            when = "jj root"
            format = "on [$symbol ($output)]($style) "
            symbol = "🐦"
            style = "bold purple"
            ignore_timeout = True
        }
        jj_empty = {
            description = "Shows (empty) in green if the working copy has no changes"
            command = "echo \"(empty)\""
            when = "jj log --no-graph -r=@ -T='if(empty, \"y\", \"\")' | grep -q '^y$'"
            format = "[$output]($style) "
            style = "bold green"
            ignore_timeout = True
        }
        jj_desc = {
            description = "The description of your working copy, if set"
            command = "jj log --no-graph -r=@ -T='if(description, description.first_line(), \"(no description)\")'"
            when = "jj root"
            format = "$symbol [($output)]($style) "
            symbol = "|"
            ignore_timeout = True
        }
    }
    shell = {
        disabled = False
        format = "[$indicator]($style) "
    }
}
