# Agent Guidelines

## Task Management with Backlog.md

This project uses Backlog.md MCP for all task and project management activities when enabled.

**CRITICAL GUIDANCE**

- If your client supports MCP resources, read `backlog://workflow/overview` to understand when and how to use Backlog for this project.
- If your client only supports tools or the above request fails, call `backlog.get_workflow_overview()` tool to load the tool-oriented overview (it lists the matching guide tools).

- **First time working here?** Read the overview resource IMMEDIATELY to learn the workflow
- **Already familiar?** You should have the overview cached ("## Backlog.md Overview (MCP)")
- **When to read it**: BEFORE creating tasks, or when you're unsure whether to track work

These guides cover:
- Decision framework for when to create tasks
- Search-first workflow to avoid duplicates
- Links to detailed guides for task creation, execution, and completion
- MCP tools reference

You MUST read the overview resource to understand the complete workflow. The information is NOT summarized here.

## Skills & Standards

Reusable skills live under `~/.agents/skills/` (shared) and OpenCode's own `skills/`. Load one with the `skill` tool whenever it fits the task instead of reimplementing what it already covers.

When the current repo contains a `.lattice/` directory, it is a **Lattice project** with committed engineering standards — honor them:

- Read and follow `.lattice/standards/*.md` (architecture, clean-code, knowledge-base, language-idioms). These override generic defaults for this repo.
- Use the Lattice workflow skills for substantial work: `design-blueprint` (design a feature), `code-forge` (implement from an approved design), `refactor-safely`, `bug-fix`, and `review` (structured code review that applies `.lattice/standards`).

## Navigation & Context Discipline

Re-exploring an unfamiliar codebase every task is the single biggest recurring token cost. Orient cheaply, then read narrowly:

- **Look for a map before exploring.** Check for a `MAP.md`, a `.lattice/` knowledge base, structure notes in `AGENTS.md`, or a navigation index (`radar`, `ctags`, tree-sitter). Use it to jump to an exact `file#symbol` instead of listing trees or grepping many terms.
- **Navigate before you grep.** Prefer one targeted lookup (exact symbol / rare term) over broad directory walks and speculative reads; open the specific region you need, not whole trees.
- **Prefer deterministic tools over model exploration.** A CLI/index that returns an anchor costs no model tokens; reasoning through the tree costs many.
- **Pass anchors down.** When delegating to a subagent, hand it the paths/anchors you already found so it doesn't re-explore from scratch.

## Shell
- Before running the first command, check which shell is being used.
- **Important**: If the default shell is Nushell (`nu`), note that it is NOT POSIX compliant - use `help` command if an error is thrown for incompatible commands/syntax.
- If a POSIX shell is necessary, use `zsh`.

## Version Control
- **Use Jujutsu (jj)** when available (i.e., if the root directory has a `.jj` folder) instead of Git.
- **Commit style**: Conventional commits (e.g., `fix:`, `feat:`, `chore:`)
- **Prefer MCPs over CLIs**: When available, use the Jujutsu, GitHub, and GitLab MCP tools instead of their command-line interfaces for better integration and error handling
- **Always commit changes**: Before moving on to another topic or task, commit all changes with an appropriate conventional commit message
- **GPG signing**: Before your first commit in a session, warm the GPG cache:
  ```bash
  gpg-preset-from-keychain
  ```
  This pre-seeds gpg-agent from macOS Keychain so signing works non-interactively. If it fails, ask the user to unlock GPG manually.
