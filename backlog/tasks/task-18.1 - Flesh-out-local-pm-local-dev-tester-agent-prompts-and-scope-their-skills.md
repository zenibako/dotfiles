---
id: TASK-18.1
title: Flesh out local-pm / local-dev / tester agent prompts and scope their skills
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
- [x] #1 local-pm.md and local-dev.md contain complete, purpose-built system prompts (no longer one-line stubs), consistent with the local orchestrator's pm -> dev -> reviewer delegation flow
- [x] #2 A tester prompt exists at src/opencode/prompt/agents/tester.md and the tester agent in config.k references it via _agent_prompt("tester")
- [x] #3 local-pm, local-dev, and tester each have appropriate per-agent permission.skill scoping in config.k (only the skills the role needs)
- [x] #4 kcl run src/main.k compiles and the generated opencode.jsonc parses as valid JSON
- [x] #5 The generated agent prompt values equal the corresponding prompt-file contents (verified they load via the {file:} refs)
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 Config is deployed using Dotter. If `--force` is required, back up the previous versions.
- [x] #2 Validate results in relevant tool(s). If it's a CLI tool, try in both `zsh` and `nu`.
<!-- DOD:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Verify per-agent permission/skill scoping semantics against opencode v1.18 source (schema stripping vs execution gating).
2. Write purpose-built small-model prompts: local-pm.md, local-dev.md (rewrites), tester.md (new), each with a fixed output-contract status line; update local.md with the tester step and a 2-round fix-loop cap.
3. Scope config.k: tester → prompt + deny-all MCP + skill scoping; local-pm → Backlog-only + edit/skill deny; local-dev → deny-all MCP (CLI-first jj/git, user-approved); local → also deny edit+skill.
4. Fix latent bug: sanitize MCP server names in _deny_all_mcp/_mcp_only to match opencode's sanitized tool keys.
5. Compile (kcl run src/main.k), deploy (./deploy.sh -f with backups), validate via opencode debug agent + captured request payloads, in zsh and nu.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented with a small-model-first design (local lane = lmstudio/qwen3.5-9b):

- local-pm.md / local-dev.md rewritten as purpose-built prompts; tester.md created. All three use short imperative procedures with fixed output contracts (`PM:`/`DEV:`/`TEST:` status lines) that local.md now parses; local.md gained the tester step and a 2-round cap on the fix loop.
- Roster decision (user-approved): CLI-first for the local lane — local, local-dev, tester deny ALL MCP servers (jj/git via bash); local-pm keeps Backlog only (dropped Jujutsu — Backlog commits its own task files). Rationale: Jujutsu (~60) + GitHub (~40) tool schemas per request is fatal for a 9B model's context. tester stays on the cloud test model (user choice) but is now scoped — previously it had NO permission block and inherited every host MCP server.
- Skill scoping: local + local-pm use `"skill": "deny"` (whole skills section removed); tester denies jj-sequential-conflict-resolution only; local-dev keeps both skills. Syntax verified against opencode v1.18 source (skill/index.ts).
- Bonus fixes: (1) `_deny_all_mcp`/`_mcp_only` now sanitize server names to match opencode's MCP tool keys — patterns from multi-word names ("Home Assistant*") previously never matched (silent no-op for both context stripping and execution gating); (2) post_deploy.sh merge now uses `--replace agent` so agents removed from the KCL roster (stale test/code-review) disappear from the live file; (3) per-machine local.k migrated to src/local.k (post-128680e format) with opencode_local_agent_model=lmstudio/qwen3.5-9b.
- AC#5 evidence: captured request payloads (doc-1) contain the prompt-file headers for local/local-pm/local-dev; `opencode debug agent tester` (run from nu) prints resolved tester.md content.
- Deployed via ./deploy.sh -f; overwritten targets backed up to ~/.cache/dotfiles/backups/2026-07-20/.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Completed the local-agent roster for effective Qwen 3.5 9B coding work. local-pm/local-dev/tester now have purpose-built small-model prompts (fixed output contracts, scope guards) wired via {file:} refs; local.md orchestrates pm → dev → tester → reviewer with a capped feedback loop. Per-agent scoping now actually minimizes context: measured request footprint dropped from ~47k est. tokens (unscoped baseline, 150 tools) to ~8.5–13.7k for the local lane (10–28 tools). Also fixed a latent sanitization bug that made multi-word MCP deny patterns silent no-ops, scoped the previously-unscoped tester agent, and made post-deploy merges drop removed agents. Verified via kcl compile, JSON parse, deployed-config inspection, captured live request payloads, and opencode debug in zsh + nu.
<!-- SECTION:FINAL_SUMMARY:END -->
