---
id: TASK-18.3
title: Measure per-agent token/context burn to validate the MCP/permission scoping
status: To Do
assignee: []
created_date: '2026-07-20 14:33'
labels:
  - opencode
  - context-management
dependencies: []
references:
  - src/opencode/config.k
  - src/_shared/mcp.k
parent_task_id: TASK-18
priority: low
type: spike
ordinal: 11000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
This session reduced OpenCode agent context via three levers: excluding servers from the host MCP config (`_MCP_HOST_EXCLUDED` in src/_shared/mcp.k), per-agent `permission` wildcards denying MCP tools (`_deny_all_mcp` / `_mcp_only` in config.k), and externalizing prompts to files.

Open question flagged during the work: per the OpenCode docs, per-agent `permission: deny` is documented to gate EXECUTION, not guaranteed to remove a tool's schema from the model's context. The only documented context lever is excluding a server from the host config entirely. So the token savings from the per-agent permission scoping are currently unverified.

Goal: empirically measure whether these changes actually reduce an agent's context/token footprint, and record the findings so the approach is validated (or adjusted).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A repeatable method to measure an OpenCode agent's context/token usage (e.g., available tool count and input tokens per agent) is documented
- [ ] #2 Findings recorded quantifying: (a) whether per-agent permission:deny reduces context tokens, and (b) whether host-level MCP exclusion reduces context tokens
- [ ] #3 A short recommendation is captured (e.g., in .lattice/ or repo docs) reflecting the findings and whether to keep, drop, or change the per-agent permission scoping
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Config is deployed using Dotter. If `--force` is required, back up the previous versions.
- [ ] #2 Validate results in relevant tool(s). If it's a CLI tool, try in both `zsh` and `nu`.
<!-- DOD:END -->
