---
id: TASK-18.3
title: Measure per-agent token/context burn to validate the MCP/permission scoping
status: Done
assignee: []
created_date: '2026-07-20 14:33'
updated_date: '2026-07-20 15:52'
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
- [x] #1 A repeatable method to measure an OpenCode agent's context/token usage (e.g., available tool count and input tokens per agent) is documented
- [x] #2 Findings recorded quantifying: (a) whether per-agent permission:deny reduces context tokens, and (b) whether host-level MCP exclusion reduces context tokens
- [x] #3 A short recommendation is captured (e.g., in .lattice/ or repo docs) reflecting the findings and whether to keep, drop, or change the per-agent permission scoping
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 Config is deployed using Dotter. If `--force` is required, back up the previous versions.
- [x] #2 Validate results in relevant tool(s). If it's a CLI tool, try in both `zsh` and `nu`.
<!-- DOD:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Answer the premise at the source level: read opencode v1.18 (installed 1.18.1) tool-resolution code to determine whether per-agent permission:deny strips schemas or only gates execution.
2. Build a repeatable measurement: fake OpenAI-compatible endpoint on the configured LM Studio baseURL logging per-request tool count/bytes/system size (scripts/measure_opencode_context.py) — no model download required.
3. Measure build (baseline) vs local/local-pm/local-dev; reach subagents via a synthesized task tool call (opencode run --agent <subagent> silently falls back to build).
4. Record findings + recommendation in a Backlog doc.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Premise resolved at source level, then confirmed empirically. opencode v1.18: string-form `permission: {"Server*": "deny"}` (pattern "*") REMOVES tool schemas from the request (Permission.disabled + resolveTools in session/llm/request.ts), drops denied servers' MCP instructions from the system prompt, and hides denied subagents from the task tool description — so the per-agent scoping is a real context lever, not just an execution gate. The stale NOTE in config.k was corrected.

Measurements (scripts/measure_opencode_context.py; full table + method in Backlog doc-1 "OpenCode agent context measurements"): build baseline 150 tools / ~46.7k est. tokens per request; local 10 tools / ~8.5k; local-pm 28 tools (builtins + Backlog only) / ~10.7k; local-dev 11 tools, zero MCP / ~13.7k. 71–82% reduction — the unscoped baseline would not even fit a 32k local context window.

Recommendation (doc-1): keep per-agent permission scoping (load-bearing for the Qwen 3.5 lane), keep host-level exclusion for servers that should never spawn, keep CLI-first VCS for local agents.

Gotchas documented for reruns: `opencode run --agent <subagent>` silently falls back to build — subagents must be measured via a task invocation; task-spawned subagents run on their own configured model, so only lmstudio-routed agents hit the capture endpoint (tester/reviewer on gpt-5.4 were not captured; identical code path).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Validated the context-reduction levers empirically and at source level. Per-agent permission:deny in opencode v1.18 removes tool schemas from the model request (contrary to the task's premise from the docs), and host-level MCP exclusion removes servers entirely. Measured with a request-capturing fake endpoint (scripts/measure_opencode_context.py): the scoped local lane runs at ~8.5–13.7k est. prompt tokens vs ~46.7k unscoped — a 71–82% reduction that makes qwen3.5-9b viable in a 32k window. Findings and recommendation recorded in Backlog doc-1; recommendation: keep the scoping as-is.
<!-- SECTION:FINAL_SUMMARY:END -->
