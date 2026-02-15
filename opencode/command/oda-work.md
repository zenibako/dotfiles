---
description: Setup your workspace for a work item in the current sprint.
---

Focus the current session on Jira work item related to this query: "$ARGUMENTS"; this most likely a work item ID that has a format of ODA-XXXXX; if not, use `jira sprint list --current --raw -q "assignee = currentUser()"` to find work items assigned to you in the current sprint.

Use Jujutsu to investigate if a bookmark for the work item ID is already available:
- If so, create a new change for that bookmark and put that in focus.
- If not, create a new change from the `dp` bookmark (fallback on `main` or `master` if not available) and create the work item bookmark.

After that, reset source tracking by deploying the current state to `PG5`. 
!`sf project deploy start`

Then, suggest a solution based on the information from Jira (using `jira issue view --raw <ISSUE-ID>`) and Confluence that are related to the work item, unless the query suggests you don't do this.

If you find a solution and attempt to fix it, set the description for your change using Jujutsu to something logical using Conventional Commits format, and then show the diff. After that, create a new change.
