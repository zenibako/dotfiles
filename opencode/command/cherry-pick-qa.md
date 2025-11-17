---
description: Cherry-pick commits for a Jira work item to qa branch and monitor the GitLab pipeline.
---

Cherry-pick commits for work item "$ARGUMENTS" to the qa branch and monitor the resulting GitLab pipeline. If no work item is provided, ask the user for the work item number.

Determine the current repository location. If not in a git repository, ask the user to specify.

Get the GitLab project ID from the git remote:
!`glab repo view --json id --jq '.id'`

Or alternatively derive project path from git remote URL and URL-encode it:
!`git remote get-url origin | sed 's|.*:||' | sed 's|\.git$||'`

Find all commits for the work item across all branches:
!`git log --all --oneline --grep="$ARGUMENTS"`

Check which commits are already in the qa branch:
!`git log qa --oneline --grep="$ARGUMENTS"`

Check commits in the dp branch (or main/master if dp doesn't exist):
!`git log dp --oneline --grep="$ARGUMENTS"`

Compare the lists to identify commits in dp that are NOT in qa.

Prepare the qa branch:
!`git checkout qa`
!`git pull origin qa`

Cherry-pick the missing commits in chronological order (oldest to newest):
!`git cherry-pick <commit-hash>`

Handle any merge conflicts if they occur during cherry-pick.

Push to remote:
!`git push origin qa`

Get the latest pipeline for the qa branch using API with project ID derived earlier (with sanitization):
!`curl -s --header "PRIVATE-TOKEN: $GITLAB_TOKEN" "$GITLAB_URL/api/v4/projects/$PROJECT_ID/pipelines?ref=qa&per_page=1" | tr -d '\000-\037' | tr -d '\177' | jq -r '.[0]'`

Extract the pipeline ID from the response and monitor it by checking every 20 seconds until completion.

**CRITICAL:** Always sanitize API responses before passing to jq using `tr -d '\000-\037' | tr -d '\177'` to remove control characters.

For monitoring, get pipeline status:
!`curl -s --header "PRIVATE-TOKEN: $GITLAB_TOKEN" "$GITLAB_URL/api/v4/projects/$PROJECT_ID/pipelines/<PIPELINE_ID>" | tr -d '\000-\037' | tr -d '\177' | jq -r '.status // "unknown"'`

Get pipeline duration:
!`curl -s --header "PRIVATE-TOKEN: $GITLAB_TOKEN" "$GITLAB_URL/api/v4/projects/$PROJECT_ID/pipelines/<PIPELINE_ID>" | tr -d '\000-\037' | tr -d '\177' | jq -r '.duration // null | if . == null then "N/A" else "\(. / 60 | floor)m \(. % 60 | floor)s" end'`

Get all jobs:
!`curl -s --header "PRIVATE-TOKEN: $GITLAB_TOKEN" "$GITLAB_URL/api/v4/projects/$PROJECT_ID/pipelines/<PIPELINE_ID>/jobs" | tr -d '\000-\037' | tr -d '\177' | jq -r 'group_by(.stage) | map({stage: .[0].stage, jobs: map({name: .name, status: .status})})'`

Display job statuses organized by stage. Highlight running (🟡) and failed (❌) jobs. Use ✅ for success, ⏳ for created/pending, 🔵 for manual, ⏭️ for skipped, 🚫 for canceled.

Show pipeline status, duration, and web URL with each update.

Stop monitoring when status is not 'running', 'pending', or 'created'.

Report final status including:
- Overall pipeline result
- Summary of completed stages
- Any failed jobs with details and links using:
  !`echo "$JOBS_JSON" | tr -d '\000-\037' | tr -d '\177' | jq -r '.[] | select(.status == "failed") | "  ❌ \(.name) - \(.web_url)"'`
- Link to GitLab pipeline web URL

**Important:** GPG signing is recommended but cherry-pick preserves original signatures. Use `GITLAB_TOKEN` environment variable for API authentication. Use `GITLAB_URL` environment variable for GitLab instance URL (defaults to https://gitlab.com). Project ID is derived from the repository using `glab` or by URL-encoding the project path. Always sanitize JSON responses with `tr -d '\000-\037' | tr -d '\177'` before passing to jq to avoid control character parse errors.
