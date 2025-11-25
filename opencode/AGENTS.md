# Agent Guidelines

## Shell
- **Use Nushell** as the default shell for all commands and scripts
- Nushell provides structured data, better error handling, and cross-platform compatibility
- **Important**: Nushell is NOT POSIX compliant - always use semicolons (`;`) to separate statements

## Version Control
- **Use Jujutsu (jj)** exclusively, not git
- **Commit style**: Conventional commits (e.g., `fix:`, `feat:`, `chore:`)
- **Prefer MCPs over CLIs**: When available, use the Jujutsu, GitHub, and GitLab MCP tools instead of their command-line interfaces for better integration and error handling
- **Always commit changes**: Before moving on to another topic or task, commit all changes with an appropriate conventional commit message
