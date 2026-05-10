# Pixlet completions for Nushell
# Uses Cobra __complete API (same pattern as acli.nu)

export def "pixlet-completer" [spans: list<string>] {
    let args = ($spans | skip 1)
    let completion_args = if ($args | is-empty) { [""] } else { $args }
    let result = (do { ^pixlet __complete ...$completion_args } | complete)

    if $result.exit_code != 0 {
        return null
    }

    let lines = ($result.stdout | lines)
    if ($lines | is-empty) {
        return null
    }

    # Remove directive lines (start with :) and activeHelp markers
    $lines
    | where not ($it | str starts-with ":")
    | where not ($it | str starts-with "_activeHelp_ ")
    | each { |line|
        let parts = ($line | split row "\t")
        {
            value: ($parts | first)
            description: ($parts | skip 1 | first | default "")
        }
    }
}
