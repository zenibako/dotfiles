---
description: Continue the current task using the recommended path
---

Continue from the latest unfinished point in the current context.

Apply this decision order:

1. If execution stopped mid-task, resume from the last incomplete operation without repeating completed work.
2. If blocked only on implementation approval, proceed with the recommended option and continue.
3. If waiting on a user decision and a recommended option or clear default was already identified, choose that option and continue.
4. Otherwise, proceed with the most reasonable next step based on the existing context and repository state.

Only ask the user a question if no safe recommended/default path exists.
