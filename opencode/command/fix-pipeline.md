---
description: Check for CI/CD pipeline errors and fix them automatically
---

Detect the git remote type (GitHub or GitLab) and check for CI/CD pipeline failures, then attempt to fix them.

## Steps:

1. **Detect Remote Type:**
   - Run `git remote get-url origin` to get the remote URL
   - If it contains `github.com`, use GitHub MCP/tools
   - If it contains `gitlab.com` or other GitLab instances, use GitLab MCP/tools

2. **For GitHub (prioritize MCP):**
   - Extract owner and repo from the remote URL
   - Get the current branch name with `git branch --show-current`
   - **Try MCP first:** Use `GitHub_get_pull_request_status` to check PR CI status
   - **Fallback to CLI:** If MCP unavailable, use bash with `gh pr checks`
   - If there are failures:
     - **MCP approach:** Parse status response for failed check details
     - **CLI approach:** Use `gh run view --log-failed` to get error logs
   - Analyze the errors and attempt fixes based on common patterns:
     - Test failures: examine test output and fix the failing tests
     - Build errors: check compilation/build logs and fix syntax/dependency issues
     - Linting errors: run the linter locally and apply fixes
     - Type errors: fix type mismatches
   - After fixing, commit the changes and push

3. **For GitLab (prioritize MCP):**
   - **Try MCP first:** Use GitLab MCP tools if available to check pipeline status
   - **Fallback to CLI:** If MCP unavailable, use bash with `glab ci view` for latest pipeline
   - If there are failures:
     - **MCP approach:** Use GitLab MCP to retrieve job logs
     - **CLI approach:** Use `glab ci trace` to get job logs
   - Analyze and fix similar to GitHub process
   - Commit and push fixes

4. **Common Fix Patterns:**
   - Look for stack traces, error messages, and failed assertions
   - Check for missing dependencies in package files
   - Verify configuration files (YAML syntax, etc.)
   - Check for environment-specific issues
   - Update snapshots if needed for snapshot tests

5. **Verification:**
   - After pushing fixes, wait briefly and check CI status again
   - Report the status to the user
   - If still failing, provide details on remaining issues

## Notes:
- If no PR/MR exists for the current branch, inform the user
- If there are no CI failures, report success
- Always explain what fixes were applied
- If unable to automatically fix, provide detailed diagnostics for manual intervention
