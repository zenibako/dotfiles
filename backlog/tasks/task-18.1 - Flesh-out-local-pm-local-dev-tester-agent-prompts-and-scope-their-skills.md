---
id: TASK-18.1
title: Flesh out local-pm / local-dev / tester agent prompts and scope their skills
status: In Progress
assignee: []
created_date: '2026-07-20 14:33'
updated_date: '2026-07-20 15:23'
labels:
  - opencode
  - context-management
dependencies: []
references:
  - src/opencode/config.k
  - src/opencode/prompt/agents/local-pm.md
  - src/opencode/prompt/agents/local-dev.md
  - src/opencode/prompt/agents/local.md
parent_task_id: TASK-18
priority: medium
type: enhancement
ordinal: 9000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The "Phase 2" roster work for the global OpenCode agents (src/opencode/config.k `_agent` dict).

Current state: the `local-pm` and `local-dev` prompts (src/opencode/prompt/agents/local-pm.md and local-dev.md) are one-line placeholder stubs; the `tester` subagent has no prompt file at all. Prompts are loaded at runtime via `{file:~/.config/opencode/prompt/agents/<name>.md}` (see the `_agent_prompt` helper in config.k). Per-agent MCP access is already scoped via the `_deny_all_mcp` / `_mcp_only` permission helpers; skill access is not yet scoped.

Goal: give these three subagents real, purpose-built system prompts consistent with the `local` orchestrator's delegation flow (the orchestrator in local.md delegates local-pm → local-dev → reviewer and passes file#symbol anchors down), and scope which skills each may load.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 local-pm.md and local-dev.md contain complete, purpose-built system prompts (no longer one-line stubs), consistent with the local orchestrator's pm -> dev -> reviewer delegation flow
- [ ] #2 A tester prompt exists at src/opencode/prompt/agents/tester.md and the tester agent in config.k references it via _agent_prompt("tester")
- [ ] #3 local-pm, local-dev, and tester each have appropriate per-agent permission.skill scoping in config.k (only the skills the role needs)
- [ ] #4 kcl run src/main.k compiles and the generated opencode.jsonc parses as valid JSON
- [ ] #5 The generated agent prompt values equal the corresponding prompt-file contents (verified they load via the {file:} refs)
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Config is deployed using Dotter. If `--force` is required, back up the previous versions.
- [ ] #2 Validate results in relevant tool(s). If it's a CLI tool, try in both `zsh` and `nu`.
<!-- DOD:END -->
