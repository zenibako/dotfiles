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
