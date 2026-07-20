---
name: jj
description: >
  Jujutsu (jj) version control workflows including commits, bookmarks, conflict resolution,
  and GPG signing. Use when working with version control, committing changes, managing branches,
  or resolving merge conflicts.
compatibility: Requires jj (Jujutsu) CLI installed. GPG required for commit signing.
metadata:
  author: chanderson
  version: "1.0"
---

# Jujutsu (jj) Version Control

## When to use

- When committing, describing, or managing changes
- When working with bookmarks (branches)
- When resolving merge conflicts
- When interacting with Git remotes

## Core Concepts

Jujutsu uses a different model than Git:

- **Working copy is always a commit** — no staging area, no "unstaged changes"
- **`@`** refers to the current working-copy commit
- **Bookmarks** are jj's equivalent of Git branches
- **Changes are immutable** — operations create new versions, old ones are preserved in the operation log
- **Conflicts are first-class** — they can be committed and resolved later

## Common Workflows

### Committing Changes

```bash
# Describe the current working-copy commit and create a new empty one on top
jj commit -m "feat: add new feature"

# Just update the description without creating a new commit
jj describe -m "fix: correct typo in config"
```

### Viewing History

```bash
# Show the log (default command)
jj log

# Show a specific commit
jj show <revision>

# Show diff of current changes
jj diff
```

### Working with Bookmarks (Branches)

```bash
# Create a bookmark
jj bookmark create <name>

# Move a bookmark to current commit
jj bookmark set <name>

# List bookmarks
jj bookmark list

# Push to remote
jj git push
```

### Conflict Resolution

Conflicts are resolved using `jj-diffconflicts` via Neovim:

```bash
# Resolve conflicts interactively
jj resolve
```

The merge tool (`diffconflicts`) opens Neovim with a 3-way diff view.

### Interacting with Git

```bash
# Fetch from remote
jj git fetch

# Push bookmarks to remote
jj git push

# Import Git refs
jj git import
```

### Undoing Mistakes

```bash
# Undo the last operation
jj operation undo

# View operation history
jj operation log

# Restore to a specific operation
jj operation restore <op-id>
```

## GPG Signing

All commits are GPG signed automatically via `jj/config.toml`:

```toml
[signing]
behavior = "own"
backend = "gpg"
```

Do not disable signing or bypass it. If signing fails, troubleshoot the GPG agent rather than skipping.

## Agent Guidelines

- **Agents MUST NOT commit changes directly.** Instead, prompt the user to commit with: `jj commit -m "message"`
- Always suggest descriptive commit messages following conventional commits format
- Use `jj status` and `jj diff` to understand the current state before suggesting actions
- Use `jj log` to understand recent history and branch structure
- **Prefer `--git` format option:** When using `jj` commands that display output (e.g., `jj log`, `jj show`, `jj diff`, `jj status`), always pass `--git` to produce Git-compatible output. This ensures consistency with Git tooling and avoids confusing non-jj-native formats. Example: `jj log --git`, `jj diff --git`, `jj show --git`.

## Commit Attribution (Co-authored-by)

When prompting the user to commit (or if committing directly when allowed), ensure the commit includes proper AI co-author attribution.

**For Jujutsu**, use the `jjc`/`jjd` shell helpers (defined in `zshrc`) which automatically respect the `$AI_CO_AUTHOR` environment variable. **Note**: `jjc` and `jjd` are zsh functions defined in `~/.zshrc`, so they are only available in interactive shells. In non-interactive contexts (e.g., MCP server execution), source `~/.zshrc` first or use the manual fallback.

```bash
# Preferred (interactive shells only)
AI_CO_AUTHOR="Kimi <kimi-k2.6:cloud@ai>" jjc "feat: add new feature"

# Non-interactive fallback — source zshrc first
source ~/.zshrc && AI_CO_AUTHOR="Kimi <kimi-k2.6:cloud@ai>" jjc "feat: add new feature"

# Or use the manual inline command (works everywhere)
jj new main && jj describe -m "feat: add new feature

Co-authored-by: Kimi <kimi-k2.6:cloud@ai>"
```

### Full workflow: commit + advance bookmark + push

After committing changes on a tracked bookmark (like `main`):

1. **Check bookmark state**: `jj bookmark list`
2. **Advance the bookmark** if it lags behind the latest commit: `jj bookmark move <bookmark> --to <new-head>`

`jjc` / `jjd` helpers do step 2 automatically — they run `jj new <commit>` after committing, keeping the working copy on the latest change.

### Pushing to remote

After committing and advancing, push with:

```bash
jj git push
```

If the bookmark points to a new commit and is at the same commit as its remote tracking branch, jj will skip it. If it differs, it pushes the bookmark forward on the remote too.

To push ALL bookmarks (and advance them on the remote):

```bash
jj git push --all
```

| Profile | Model | Co-authored-by |
|---|---|---|
| Personal | `opencode-go/glm-5.2` | `GLM <glm-5.2@ai>` |
| Work | `openai/gpt-5.4` | `GPT-5.4 <gpt-5.4@ai>` |
| Plan/Test | Check `opencode_*_agent_model` | Use the model name from config |

## Gotchas

- There is no `jj add` — all files in the working copy are automatically tracked
- `jj commit` creates a new empty commit on top; it does NOT amend like `git commit --amend`
- Bookmarks must be explicitly pushed with `jj git push`
- The working copy commit (`@`) always exists and is mutable — use `jj describe` to update its message
- Rebase is non-destructive; the old commits remain in the operation log
- **`jjc` and `jjd` are interactive only**: These are zsh functions defined in `~/.zshrc`. In non-interactive contexts (e.g., MCP tools, scripts), they are not available. Use `source ~/.zshrc && jjc "..."` as a fallback, or use the manual `jj commit -m` / `jj describe -m` commands with the `Co-authored-by` line appended.
