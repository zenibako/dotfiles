---
description: Monitor a GitLab pipeline for the current repository branch.
---

Monitor the GitLab pipeline for branch "$ARGUMENTS". If no branch is provided, determine the current branch using Jujutsu or Git. If there's no remote or the branch isn't clear, ask the user to clarify.

Get the GitLab project ID from the git remote:
!`glab repo view --json id --jq '.id'`

Or alternatively derive project path from git remote URL and URL-encode it:
!`git remote get-url origin | sed 's|.*:||' | sed 's|\.git$||'`

Get the latest pipeline for the branch using API with project ID derived earlier:
!`curl -s --header "PRIVATE-TOKEN: $GITLAB_TOKEN" "$GITLAB_URL/api/v4/projects/$PROJECT_ID/pipelines?ref=<BRANCH>&per_page=1" | jq -r '.[0]'`

Extract pipeline ID and web URL from the response.

Monitor the pipeline by checking every 20 seconds until completion. Use a loop that fetches pipeline and job status.

**CRITICAL:** Always sanitize API responses before passing to jq to remove control characters. Use one of these methods:
- `tr -d '\000-\037' | tr -d '\177'` to strip control characters
- `sed 's/[[:cntrl:]]//g'` with `LC_ALL=C` set

Get pipeline status and extract using jq (with sanitization):
!`curl -s --header "PRIVATE-TOKEN: $GITLAB_TOKEN" "$GITLAB_URL/api/v4/projects/$PROJECT_ID/pipelines/<PIPELINE_ID>" | tr -d '\000-\037' | tr -d '\177' | jq -r '.status // "unknown"'`

Get pipeline duration (convert to minutes and seconds):
!`curl -s --header "PRIVATE-TOKEN: $GITLAB_TOKEN" "$GITLAB_URL/api/v4/projects/$PROJECT_ID/pipelines/<PIPELINE_ID>" | tr -d '\000-\037' | tr -d '\177' | jq -r '.duration // null | if . == null then "N/A" else "\(. / 60 | floor)m \(. % 60 | floor)s" end'`

Get all jobs and organize by stage using jq (with sanitization):
!`curl -s --header "PRIVATE-TOKEN: $GITLAB_TOKEN" "$GITLAB_URL/api/v4/projects/$PROJECT_ID/pipelines/<PIPELINE_ID>/jobs" | tr -d '\000-\037' | tr -d '\177' | jq -r 'group_by(.stage) | map({stage: .[0].stage, jobs: map({name: .name, status: .status})})'`

Display jobs organized by stage with status icons. Use jq to process the jobs JSON and map statuses to icons:
- 🟡 for "running"
- ✅ for "success"  
- ❌ for "failed"
- ⏳ for "created" or "pending"
- 🔵 for "manual"
- ⏭️ for "skipped"
- 🚫 for "canceled"

Use `clear` to refresh the display on each iteration for a live monitoring experience.

Stop monitoring when status is not "running", "pending", or "created".

When pipeline completes, report final status including:
- Final status (success, failed, canceled)
- Total duration
- Link to pipeline web URL
- List of failed jobs (if any) with their web URLs using:
  !`echo "$JOBS_JSON" | tr -d '\000-\037' | tr -d '\177' | jq -r '.[] | select(.status == "failed") | "  ❌ \(.name) - \(.web_url)"'`

**Important:** Use `GITLAB_TOKEN` environment variable for API authentication. Use `GITLAB_URL` environment variable for GitLab instance URL (defaults to https://gitlab.com). Project ID is derived from the repository. Always sanitize JSON responses with `tr -d '\000-\037' | tr -d '\177'` before passing to jq to avoid control character parse errors.
