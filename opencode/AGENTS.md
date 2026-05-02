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

## Home Assistant Config Safety

When working on this Home Assistant project, **NEVER** run operations that would destroy or overwrite the live Home Assistant configuration stored in `/config/.storage/`. This includes:

- **Never run `git clean -fd`** on the HA host — this permanently deletes untracked files including `.storage/`, runtime data, Python libraries, and addon configs.
- **Never run `git reset --hard`** on the HA host unless the working tree is confirmed safe.
- **Never force-push git changes** to the HA host if it would overwrite local modifications.
- **Always use `--dry-run` first** with any destructive git command (e.g., `git clean -fd -n`).
- **Never delete `.storage/`**, `*.db`, or runtime files manually on the HA host.

If you need to clean or reset the repository on the HA host, **only do so after stopping HA core first** and **after confirming a fresh backup exists**.

## Shell
- Before running the first command, check which shell is being used.
- **Important**: If the default shell is Nushell (`nu`), note that it is NOT POSIX compliant - use `help` command if an error is thrown for incompatible commands/syntax.
- If a POSIX shell is necessary, use `zsh`.

## Version Control
- **Use Jujutsu (jj)** when available (i.e., if the root directory has a `.jj` folder) instead of Git.
- **Commit style**: Conventional commits (e.g., `fix:`, `feat:`, `chore:`)
- **Prefer MCPs over CLIs**: When available, use the Jujutsu, GitHub, and GitLab MCP tools instead of their command-line interfaces for better integration and error handling
- **Always commit changes**: Before moving on to another topic or task, commit all changes with an appropriate conventional commit message

## Commit Attribution (Co-authored-by)

When making commits on behalf of the user, **always include the AI co-author attribution** in the commit message body:

```
fat: add new feature

Implementation details...

Co-authored-by: Kimi <kimi-k2.6:cloud@ai>
```

- This must be the **last line** of the commit message body, separated by a blank line.
- It applies to **all commits** made by the agent (Git or Jujutsu).

### Git Commits

The Git `prepare-commit-msg` hook automatically appends `Co-authored-by`. It respects the `$AI_CO_AUTHOR` environment variable if set, otherwise falls back to `Co-authored-by: AI Model <ai@example.com>`.

**Before committing, set the env var:**

```bash
AI_CO_AUTHOR="Kimi <kimi-k2.6:cloud@ai>" git commit -m "feat: add new feature"

# Or use the convenience wrapper (passes through to git commit)
AI_CO_AUTHOR="Kimi <kimi-k2.6:cloud@ai>" gitc -m "feat: add new feature"
```

### Jujutsu (jj) Commits

JJ configs do not support environment variable interpolation, but the shell helpers `jjc` and `jjd` handle attribution automatically using `$AI_CO_AUTHOR`:

```bash
# Commit with proper attribution
AI_CO_AUTHOR="Kimi <kimi-k2.6:cloud@ai>" jjc "feat: add new feature"

# Describe working copy without creating new commit
AI_CO_AUTHOR="Kimi <kimi-k2.6:cloud@ai>" jjd "fix: correct typo"
```

If not using the wrappers, manually append the trailer:
```bash
jj commit -m "feat: add new feature

Co-authored-by: Kimi <kimi-k2.6:cloud@ai>"
```

### Required Action Before Committing

1. **Identify the active model**: Check the `opencode_*_agent_model` variables in `.dotter/global.toml` (e.g., `opencode_build_agent_model` for the build agent)
2. **Set the env var**: Export `AI_CO_AUTHOR` with the correct identity
3. **Commit**: Use `git commit`, `gitc`, `jjc`, or `jjd`

### Model Identity Mapping

| Profile | Model (as of current config) | Co-authored-by |
|---|---|---|
| Personal | `ollama-cloud/kimi-k2.6:cloud` | `Kimi <kimi-k2.6:cloud@ai>` |
| Work | `openai/gpt-5.4` | `GPT-5.4 <gpt-5.4@ai>` |
| Plan/Test | Check `opencode_*_agent_model` | Use the model name from config |

**Format**: Extract the model name from the config value. For `ollama-cloud/kimi-k2.6:cloud`, use `Kimi <kimi-k2.6:cloud@ai>`. For `openai/gpt-5.4`, use `GPT-5.4 <gpt-5.4@ai>`.

**Note**: The `gitc`, `jjc`, and `jjd` shell functions are defined in `zshrc` and deployed via dotter. Reload your shell or source `~/.zshrc` to use them.

## Atlassian CLI
- **Use `acli`** for all Jira and Confluence operations (replaces legacy `jira-cli`)
- **Authentication**: Use `acli auth login` or product-specific `acli {jira|rovodev} auth login`; token-based auth is supported where applicable
- **Work items**: Use `acli jira workitem` commands (not `jira issue`)
  - Search: `acli jira workitem search --jql "JQL_QUERY" --json`
  - View: `acli jira workitem view WORK-ITEM-ID --json`
  - Create: `acli jira workitem create --project KEY --type Task --summary "..." --json`
- **All commands support `--json`** for structured output parsing

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

### Plan Agent Responsibilities

When working as the Plan agent with Backlog.md:

1. **Task Assessment**: Evaluate user requests to determine if they require task tracking
   - Create tasks for work requiring planning or decision-making
   - Skip tasks for trivial/mechanical changes or informational requests

2. **Search First**: Always search existing tasks before creating new ones using `task_search` or `task_list` with filters

3. **Scope and Structure**: 
   - Assess if work is a single atomic task or multi-task feature
   - Choose appropriate structure (subtasks vs dependencies)
   - Create parent tasks with subtasks for tightly coupled work on the same component
   - Use separate tasks with dependencies for work spanning different components

4. **Task Creation**:
   - Write clear titles and descriptions explaining the WHY (outcome and user value)
   - Define specific, testable acceptance criteria (the WHAT)
   - Never embed implementation details in titles, descriptions, or acceptance criteria
   - Document task relationships and dependencies

5. **Report Created Tasks**: After creation, show the user task IDs, titles, and acceptance criteria

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
