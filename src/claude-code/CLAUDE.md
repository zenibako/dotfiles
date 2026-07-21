# Agent Guidelines

## Task Management with Backlog.md

When Backlog.md MCP is available, use it for all task and project management activities.

- If your client supports MCP resources, read `backlog://workflow/overview` to understand when and how to use Backlog for this project.
- If your client only supports tools or the above request fails, call `backlog.get_workflow_overview()` tool to load the tool-oriented overview (it lists the matching guide tools).
- **First time working here?** Read the overview resource IMMEDIATELY to learn the workflow.
- **When to read it**: BEFORE creating tasks, or when you're unsure whether to track work.

These guides cover:
- Decision framework for when to create tasks
- Search-first workflow to avoid duplicates
- Links to detailed guides for task creation, execution, and completion
- MCP tools reference

You MUST read the overview resource to understand the complete workflow. The information is NOT summarized here.

## Home Assistant Config Safety

When working on the Home Assistant project, **NEVER** run operations that would destroy or overwrite the live Home Assistant configuration stored in `/config/.storage/`. This includes:

- **Never run `git clean -fd`** on the HA host — this permanently deletes untracked files including `.storage/`, runtime data, Python libraries, and addon configs.
- **Never run `git reset --hard`** on the HA host unless the working tree is confirmed safe.
- **Never force-push git changes** to the HA host if it would overwrite local modifications.
- **Always use `--dry-run` first** with any destructive git command (e.g., `git clean -fd -n`).
- **Never delete `.storage/`**, `*.db`, or runtime files manually on the HA host.

If you need to clean or reset the repository on the HA host, **only do so after stopping HA core first** and **after confirming a fresh backup exists**.

## Shell

- Before running the first command, check which shell is being used.
- **Important**: If the default shell is Nushell (`nu`), note that it is NOT POSIX compliant — use `help` command if an error is thrown for incompatible commands/syntax.
- If a POSIX shell is necessary, use `zsh`.

## Browser & UI Investigations

When automating a browser or investigating UI behavior, **prefer the cmux browser CLI over the Chrome DevTools MCP and Playwright MCP servers whenever running in a cmux context.** In Claude Code those MCP servers are first-class tools while cmux is "just" a Bash CLI, so cmux loses by default unless this preference is stated.

- **Detect the cmux context**: any `CMUX_*` env var is set (e.g. `CMUX_SURFACE_ID`, `CMUX_SOCKET_PATH`). Quick check: `env | grep -q '^CMUX_'`.
- **In a cmux context** → drive the browser with `cmux --json browser ...` (open, snapshot, click, fill, wait, eval, screenshot). See `.agents/skills/e2e-testing/SKILL.md` → Backend 1 for the command reference.
- **Not in a cmux context** → fall back to Playwright MCP when the repo has E2E test scripts, otherwise Chrome DevTools MCP.
- **Exception**: Chrome DevTools MCP remains the right tool for DevTools-only work — Lighthouse audits, network inspection, performance/heap traces — even inside cmux, since the cmux browser CLI doesn't cover those.

## Version Control

- **Use Jujutsu (jj)** when available (i.e., if the root directory has a `.jj` folder) instead of Git.
- **Commit style**: Conventional commits (e.g., `fix:`, `feat:`, `chore:`, `docs:`)
- **Prefer MCPs over CLIs**: When available, use the Jujutsu, GitHub, and GitLab MCP tools instead of their command-line interfaces for better integration and error handling.
- **Always commit changes**: Before moving on to another topic or task, commit all changes with an appropriate conventional commit message.
- **GPG signing**: The gpg-agent passphrase cache is warmed automatically (dotfiles-managed `gpg-warm-agent`: login shells, a launchd/systemd 6h timer, and every deploy), so signing works without a TTY. If signing still fails, run `~/.local/bin/gpg-warm-agent` manually or ask the user to store the passphrase in the OS secret store (see comments in that script).

## Destructive Operations — Always Ask First

Before executing any operation that could lose uncommitted changes or rewrite history:
1. Explain what the operation will do and what data could be lost.
2. Show the current state (e.g., `jj status`, `jj log`, or `git status`).
3. Ask for explicit user confirmation before proceeding.

Operations requiring confirmation include: `git reset --hard`, `git push --force`, `git clean -fd`, `jj abandon`, `jj operation restore`, `jj git push --force`, and equivalent MCP tool calls.

## Atlassian CLI

- **Use `acli`** for all Jira and Confluence operations (replaces legacy `jira-cli`).
- **Authentication**: Use `acli auth login` or product-specific `acli {jira|rovodev} auth login`; token-based auth is supported where applicable.
- **Work items**: Use `acli jira workitem` commands (not `jira issue`):
  - Search: `acli jira workitem search --jql "JQL_QUERY" --json`
  - View: `acli jira workitem view WORK-ITEM-ID --json`
  - Create: `acli jira workitem create --project KEY --type Task --summary "..." --json`
- **All commands support `--json`** for structured output parsing.
