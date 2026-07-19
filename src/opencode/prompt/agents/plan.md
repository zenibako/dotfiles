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
