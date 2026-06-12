export def "acli-completer" [spans: list<string>] {
    let args = ($spans | skip 1)
    let completion_args = if ($args | is-empty) { [""] } else { $args }
    let result = (do { ^acli __complete ...$completion_args } | complete)

    if $result.exit_code != 0 {
        return null
    }

    let lines = ($result.stdout | lines)
    if ($lines | is-empty) {
        return null
    }

    $lines
    | where not ($it | str starts-with ":")
    | each { |line|
        let parts = ($line | split row "\t")
        {
            value: ($parts | first)
            description: ($parts | skip 1 | first | default "")
        }
    }
}
