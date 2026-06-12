# Opencode completions for Nushell
# Uses yargs --get-yargs-completions API (not Cobra)
# Output format: "value:description" per line

export def "opencode-completer" [spans: list<string>] {
    let args = ($spans | skip 1)
    let completion_args = if ($args | is-empty) { [""] } else { $args }
    let result = (do { ^opencode --get-yargs-completions ...$completion_args } | complete)

    if $result.exit_code != 0 {
        return null
    }

    let lines = ($result.stdout | lines)
    if ($lines | is-empty) {
        return null
    }

    # yargs format: "value:description" or just "value"
    $lines
    | each { |line|
        let parts = ($line | split row ":")
        if ($parts | length) >= 2 {
            {
                value: ($parts | first)
                description: ($parts | skip 1 | str join ":")
            }
        } else {
            { value: $line, description: "" }
        }
    }
}
