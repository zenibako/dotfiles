---
id: TASK-10
title: Reconcile Claude config drift and update SonarQube MCP runtime
status: In Progress
assignee:
  - OpenCode
created_date: '2026-06-06 12:28'
updated_date: '2026-06-06 12:32'
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

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Update the managed Claude templates so Dotter owns the current intended settings instead of leaving them as target-only drift. This includes enabling the missing Claude Code clangd plugin through Dotter variables and adding the stable Claude Desktop preferences that currently exist only in the local target file.
2. Update the managed SonarQube MCP configuration to use the `colima` Docker context instead of `desktop-linux`.
3. Apply the same SonarQube Colima fix to the live local Claude config in `~/.claude.json` and remove the legacy `MCP_DOCKER` server entry.
4. Back up the local Claude target files, reconcile the stale Dotter rename/cache state if needed, and run a forced Dotter deploy only if necessary to bring the managed targets back into sync.
5. Verify with `dotter deploy --dry-run` and targeted readbacks of the generated configs.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Confirmed the desired SonarQube Docker runtime should be hard-pinned to the `colima` context.
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Config is deployed using Dotter. If `--force` is required, back up the previous versions.
- [ ] #2 Validate results in relevant tool(s). If it's a CLI tool, try in both `zsh` and `nu`.
<!-- DOD:END -->
