---
id: TASK-5
title: Add Co-authored-by AI attribution to all Git and Jujutsu commits via dotter
status: In Progress
assignee: []
created_date: '2026-05-02 22:48'
labels:
  - dotfiles
  - git
  - jj
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Configure Git and Jujutsu to automatically append a Co-authored-by trailer for AI-generated commits across all repos, deployed centrally via dotter. This ensures transparency and proper attribution when OpenCode makes commits on behalf of the user.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Git configured with commit template and hooks that automatically append Co-authored-by for AI commits across all repos
- [ ] #2 Jujutsu (jj) configured with default description template that includes Co-authored-by line
- [ ] #3 OpenCode AGENTS.md updated with clear instructions for the agent to use Co-authored-by in all commits
- [ ] #4 dotter deployment tested successfully on macOS (and optionally Linux)
- [ ] #5 git commit aliases updated to include Co-authored-by for manual commits
- [ ] #6 All files deployed via dotter and properly templated for cross-machine deployment
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Config is deployed using Dotter. If `--force` is required
- [ ] #2 back up the previous versions.
- [ ] #3 Validate results in relevant tool(s). If its a CLI tool
- [ ] #4 try in both `zsh` and `nu`.
<!-- DOD:END -->
