---
description: Trigger a code review via the code-review subagent
---

The user wants a code review. Use the `task` tool with `subagent_type: "code-review"` to perform this review.

If the user provided arguments after `/review`, pass them to the subagent in the task prompt. Typical arguments:
- Empty or nothing → review uncommitted changes
- A commit hash → review that commit
- A branch name → review diff vs that branch
- A PR URL or number → review that PR
