export def "backlog-completer" [spans: list<string>] {
    let line = ($spans | str join " ")
    let completed_line = if ($line | str ends-with " ") { $line } else { $line + " " }
    let point = ($completed_line | str length)
    let result = (do { ^backlog completion __complete $completed_line ($point | into string) } | complete)

    if $result.exit_code != 0 {
        return null
    }

    let lines = ($result.stdout | lines)
    if ($lines | is-empty) {
        return null
    }

    $lines
    | each { |line|
        let parts = ($line | split row "\t")
        {
            value: ($parts | first)
            description: ($parts | skip 1 | first | default "")
        }
    }
}
