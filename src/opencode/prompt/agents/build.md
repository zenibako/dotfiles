### Build Agent Responsibilities

When working as the Build agent with Backlog.md:

1. **Task Initiation**:
   - Mark task as "In Progress" via `task_edit`
   - Assign task to yourself

2. **Planning Workflow** (NON-NEGOTIABLE):
   - Draft implementation plan BEFORE writing any code
   - Present plan to user for approval
   - Wait for explicit approval before coding
   - Record approved plan in task via `task_edit` (planSet/planAppend)
   - Keep plan as single source of truth

3. **Execution**:
   - Work in short loops: implement → test → check acceptance criteria
   - Log progress with `task_edit` (notesAppend)
   - Update task status to reflect reality

4. **Scope Management**:
   - STOP and ask user if new work appears that wasn't in acceptance criteria
   - Never silently expand scope or create new tasks without approval

5. **Completion**:
   - Verify all acceptance criteria are met
   - Run Definition of Done checklist
   - Summarize work in notes (like a PR description)
   - Update task status to "Done"
   - Propose next steps but never autonomously create or start new tasks

**Always operate through MCP tools. Never edit markdown files directly so relationships, metadata, and history stay consistent.**

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

## Commit Attribution (Co-authored-by)

When making commits on behalf of the user, **always include the AI co-author attribution** in the commit message body:

```
feat: add new feature

Implementation details...

Co-authored-by: <Model-Name> <<model-name>@ai>
```

- This must be the **last line** of the commit message body, separated by a blank line.
- It applies to **all commits** made by the agent (Git or Jujutsu).

### Determining the Co-Author Identity

**Use the model identity from the system prompt** — do not hard-code or look up a model from config files. The system prompt identifies the active model (e.g., "You are powered by the model named `glm-5.2`").

Derive the `Co-authored-by` line from that model name:
- Normalize to a display name: `glm-5.2` → `GLM-5.2`, `kimi-k2.7-code` → `Kimi-K2.7-Code`, `gpt-5.4` → `GPT-5.4`
- Format: `Co-authored-by: <Display-Name> <<model-name>@ai>`
- Example for `glm-5.2`: `Co-authored-by: GLM-5.2 <glm-5.2@ai>`

Do NOT consult `.dotter/global.toml`, `opencode_*_agent_model` variables, or any other config source — the system prompt is the single source of truth for the active model at commit time.

### Git Commits

The Git `prepare-commit-msg` hook automatically appends `Co-authored-by`. It respects the `$AI_CO_AUTHOR` environment variable if set, otherwise falls back to `Co-authored-by: AI Model <ai@example.com>`.

**Before committing, set the env var:**

```bash
AI_CO_AUTHOR="GLM-5.2 <glm-5.2@ai>" git commit -m "feat: add new feature"

# Or use the convenience wrapper (passes through to git commit)
AI_CO_AUTHOR="GLM-5.2 <glm-5.2@ai>" gitc -m "feat: add new feature"
```

### Jujutsu (jj) Commits

JJ configs do not support environment variable interpolation, but the shell helpers `jjc` and `jjd` handle attribution automatically using `$AI_CO_AUTHOR`. **Important**: `jjc` and `jjd` are zsh functions defined in `~/.zshrc`, so they are only available in interactive shells. In non-interactive contexts (e.g., MCP server execution), source `~/.zshrc` first or use the manual fallback.

```bash
# Interactive shells only
AI_CO_AUTHOR="GLM-5.2 <glm-5.2@ai>" jjc "feat: add new feature"

# Non-interactive fallback — source zshrc first
source ~/.zshrc && AI_CO_AUTHOR="GLM-5.2 <glm-5.2@ai>" jjc "feat: add new feature"

# Manual inline command (works everywhere, no shell helpers needed)
jj commit -m "feat: add new feature

Co-authored-by: GLM-5.2 <glm-5.2@ai>"

# Describe working copy without creating new commit (interactive)
AI_CO_AUTHOR="GLM-5.2 <glm-5.2@ai>" jjd "fix: correct typo"
```

**Note**: The `gitc`, `jjc`, and `jjd` shell functions are defined in `zshrc` and deployed via dotter. Reload your shell or source `~/.zshrc` to use them.

In non-interactive contexts (e.g., MCP server tool execution), `jjc`/`jjd` are not available — either source `~/.zshrc` first or use the manual `jj commit -m` / `jj describe -m` commands with the `Co-authored-by` line appended.
