---
id: TASK-7
title: Fix dotter deploy validation failures
status: In Progress
assignee: []
created_date: '2026-05-14 00:20'
labels:
  - bug
  - dotter
  - deployment
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Fix three validation failures blocking dotter deploy:
1. Pre-deploy script path resolution error (validate_schema.sh not found from cache)
2. AeroSpace CLI --config-path flag not supported (should use AEROSPACE_CONFIG env var)
3. OpenCode JSONC schema rejecting ollama-cloud model IDs (need to find correct model format or suppress schema check)
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 dotter deploy pre-deploy hook finds validate_schema.sh correctly
- [ ] #2 AeroSpace config validation passes using correct CLI invocation
- [ ] #3 Post-deploy validation completes without errors
- [ ] #4 Deployed configs are syntactically valid
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Config is deployed using Dotter. If `--force` is required, back up the previous versions.
- [ ] #2 Validate results in relevant tool(s). If it's a CLI tool, try in both `zsh` and `nu`.
<!-- DOD:END -->
