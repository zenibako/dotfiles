---
id: TASK-10
title: Reconcile Claude config drift and update SonarQube MCP runtime
status: Done
assignee:
  - OpenCode
created_date: '2026-06-06 12:28'
updated_date: '2026-06-06 13:55'
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
  - .dotter/local.toml
  - ~/.claude.json
  - ~/.config/colima/default/colima.yaml
priority: high
ordinal: 1000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Bring the dotter-managed Claude and opencode configuration back into sync with local target files so deploys no longer skip those files, and update the SonarQube MCP setup to use the intended local Colima-based runtime instead of the old Docker-specific configuration.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Dotter no longer reports drift-related skips for the Claude Desktop config or Claude Code settings caused by repository-managed differences.
- [x] #2 The repository templates reflect the intended current local Claude configuration rather than relying on manual target-only edits.
- [x] #3 The SonarQube MCP configuration no longer depends on the old Docker-specific setup and is updated for the intended Colima-based local runtime.
- [x] #4 Legacy MCP_DOCKER-related configuration is removed from the managed configuration where it is no longer needed.
- [x] #5 A dry-run validation shows the updated managed files reconcile cleanly, or any remaining skips are explained by unmanaged local-only changes outside this task's scope.
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Forced Dotter deploy succeeded after clearing the stale cache/rename state. Verified the active rendered OpenCode config no longer contains `MCP_DOCKER`, Colima can now pull `mcp/sonarqube:latest`, and the SonarQube MCP container starts successfully against `https://sonarqube.odaseva.net`.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Reconciled the Dotter-managed Claude targets with the intended local settings, enabled the managed Claude Code clangd plugin, updated the managed and local SonarQube MCP runtime to use Docker context `colima`, removed the stray local OpenCode `MCP_DOCKER` config, and fixed Colima guest trust so Docker can pull and start `mcp/sonarqube` successfully behind Netskope. Backed up the local Claude target files before forced Dotter reconciliation and validated with a successful extended `dotter deploy --dry-run`.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 Config is deployed using Dotter. If `--force` is required, back up the previous versions.
- [x] #2 Validate results in relevant tool(s). If it's a CLI tool, try in both `zsh` and `nu`.
<!-- DOD:END -->
