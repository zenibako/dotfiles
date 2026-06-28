# Agent Guidelines

## Task Management with Backlog.md

When Backlog.md MCP is available, use it for all task and project management activities.

- If your client supports MCP resources, read `backlog://workflow/overview` to understand when and how to use Backlog for this project.
- If your client only supports tools or the above request fails, call `backlog.get_workflow_overview()` tool to load the tool-oriented overview (it lists the matching guide tools).
- **First time working here?** Read the overview resource IMMEDIATELY to learn the workflow.
- **When to read it**: BEFORE creating tasks, or when you're unsure whether to track work.

## Home Assistant Config Safety

When working on the Home Assistant project, **NEVER** run operations that would destroy or overwrite the live Home Assistant configuration stored in `/config/.storage/`. This includes:

- **Never run `git clean -fd`** on the HA host — this permanently deletes untracked files including `.storage/`, runtime data, Python libraries, and addon configs.
- **Never run `git reset --hard`** on the HA host unless the working tree is confirmed safe.
- **Never force-push git changes** to the HA host if it would overwrite local modifications.
- **Always use `--dry-run` first** with any destructive git command (e.g., `git clean -fd -n`).
- **Never delete `.storage/`**, `*.db`, or runtime files manually on the HA host.

## Shell

- Before running the first command, check which shell is being used.
- **Important**: If the default shell is Nushell (`nu`), note that it is NOT POSIX compliant — use `help` command if an error is thrown for incompatible commands/syntax.
- If a POSIX shell is necessary, use `zsh`.

## Version Control

- **Use Jujutsu (jj)** when available (i.e., if the root directory has a `.jj` folder) instead of Git.
- **Commit style**: Conventional commits (e.g., `fix:`, `feat:`, `chore:`, `docs:`)
- **Always commit changes**: Before moving on to another topic or task, commit all changes with an appropriate conventional commit message.
- **GPG signing**: Before your first commit in a session, warm the GPG cache:
  ```bash
  gpg-preset-from-keychain
  ```
  This pre-seeds gpg-agent from macOS Keychain so signing works non-interactively.

## Commit Attribution (Co-authored-by)

Codex has built-in `commit_attribution` in config.toml, which handles co-author trailers automatically. When using jj instead of git, manually append the trailer:

```bash
jj commit -m "feat: add new feature

Co-authored-by: Codex <codex@ai>"
```

## Atlassian CLI

- **Use `acli`** for all Jira and Confluence operations (replaces legacy `jira-cli`).
- **Authentication**: Use `acli auth login` or product-specific `acli {jira|rovodev} auth login`.
- **Work items**: Use `acli jira workitem` commands (not `jira issue`):
  - Search: `acli jira workitem search --jql "JQL_QUERY" --json`
  - View: `acli jira workitem view WORK-ITEM-ID --json`
  - Create: `acli jira workitem create --project KEY --type Task --summary "..." --json`
- **All commands support `--json`** for structured output parsing.
