---
description: Setup your workspace for a work item in the current sprint.
---

Focus the current session on Jira work item related to this query: "$ARGUMENTS"; this most likely a work item ID that has a format of ODA-XXXXX; if not, use `acli jira workitem search --jql "assignee = currentUser() AND sprint in openSprints()" --json` to find work items assigned to you in the current sprint.

Use Jujutsu to investigate if a bookmark for the work item ID is already available:
- If so, create a new change for that bookmark, rebase it on the `trunk()` bookmark, and resolve any conflicts.
- If not, create a new change from the `trunk()` bookmark and create the work item bookmark.

Then, suggest a solution based on the information from Jira (using `acli jira workitem view <ISSUE-ID> --json`) and Confluence that are related to the work item, unless the query suggests you don't do this.

If you find a solution and attempt to fix it, set the description for your change using Jujutsu to something logical using Conventional Commits format, and then show the diff. After that, create a new change.
