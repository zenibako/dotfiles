---
description: Continue the current task using the recommended path.
---

Continue from the latest unfinished point in the current context.

Apply this decision order:

1. If execution stopped mid-task, resume from the last incomplete operation without repeating completed work.
2. If you are acting as the plan agent and are blocked only on implementation approval, switch to the build agent and continue.
3. If you are waiting on a user decision and a recommended option or clear default was already identified, choose that option and continue.
4. Otherwise, proceed with the most reasonable next step based on the existing context and repository state.

Only ask the user a question if no safe recommended/default path exists.
