---
id: TASK-10
title: Reconcile Claude config drift and update SonarQube MCP runtime
status: To Do
assignee:
  - OpenCode
created_date: '2026-06-06 12:28'
labels:
  - dotter
  - opencode
  - claude
  - sonarqube
dependencies: []
modified_files:
  - claude-code/settings.json
  - claude-desktop/claude_desktop_config.json
  - opencode/opencode.jsonc
  - .dotter/global.toml
priority: high
ordinal: 1000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Bring the dotter-managed Claude and opencode configuration back into sync with local target files so deploys no longer skip those files, and update the SonarQube MCP setup to use the intended local Colima-based runtime instead of the old Docker-specific configuration.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Dotter no longer reports drift-related skips for the Claude Desktop config or Claude Code settings caused by repository-managed differences.
- [ ] #2 The repository templates reflect the intended current local Claude configuration rather than relying on manual target-only edits.
- [ ] #3 The SonarQube MCP configuration no longer depends on the old Docker-specific setup and is updated for the intended Colima-based local runtime.
- [ ] #4 Legacy MCP_DOCKER-related configuration is removed from the managed configuration where it is no longer needed.
- [ ] #5 A dry-run validation shows the updated managed files reconcile cleanly, or any remaining skips are explained by unmanaged local-only changes outside this task's scope.
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Config is deployed using Dotter. If `--force` is required, back up the previous versions.
- [ ] #2 Validate results in relevant tool(s). If it's a CLI tool, try in both `zsh` and `nu`.
<!-- DOD:END -->
