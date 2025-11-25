# Agent Guidelines

## Shell
- Before running the first command, check which shell is being used.
- **Important**: If the default shell is Nushell (`nu`), note that it is NOT POSIX compliant - use `help` command if an error is thrown for incompatible commands/syntax.
- If a POSIX shell is necessary, use `zsh`.

## Version Control
- **Use Jujutsu (jj)** when available (i.e. if the root directory has a `.jj` folder) instead of Git.
- **Commit style**: Conventional commits (e.g., `fix:`, `feat:`, `chore:`)
- **Prefer MCPs over CLIs**: When available, use the Jujutsu, GitHub, and GitLab MCP tools instead of their command-line interfaces for better integration and error handling
- **Always commit changes**: Before moving on to another topic or task, commit all changes with an appropriate conventional commit message
