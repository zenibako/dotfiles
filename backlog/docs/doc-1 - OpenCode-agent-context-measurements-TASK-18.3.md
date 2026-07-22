---
id: doc-1
title: OpenCode agent context measurements (TASK-18.3)
type: other
created_date: '2026-07-20 15:48'
---
# OpenCode agent context measurements

Findings for TASK-18.3 — validating that the per-agent MCP/permission scoping in `src/opencode/config.k` actually reduces the model's context footprint. Measured 2026-07-20 on OpenCode 1.18.1, work profile (host MCP servers: Jujutsu, GitHub, Backlog, Atlassian, Postman, SonarQube).

## Method (repeatable)

`scripts/measure_opencode_context.py` — a fake OpenAI-compatible endpoint on 127.0.0.1:1234 (the configured LM Studio baseURL) that logs every `/v1/chat/completions` request OpenCode sends: tool count, tools-JSON bytes, system-prompt chars, request bytes, and a bytes/4 token estimate. No model download needed — the context footprint is fully determined by the request payload.

- Primary agents: `opencode run -m lmstudio/qwen3.5-9b --agent <name> "Say ok"`.
- Subagents: `opencode run --agent <subagent>` **silently falls back to build** — measure them via `"INVOKE:<subagent>"`, which makes the fake endpoint answer with a `task` tool call so the real subagent session fires.
- Caveat: task-spawned subagents run on their own configured model, so only lmstudio-routed agents land on the capture endpoint (tester/reviewer run gpt-5.4 and were not captured; they use the same code path and rule shapes as the captured agents).

## Source-level verification (opencode v1.18)

- String-form `permission: {"Server*": "deny"}` (pattern `*`) **removes the tool schema from the request**: `Permission.disabled()` + `resolveTools()` in `packages/opencode/src/session/llm/request.ts`. It is a real context lever, not just an execution gate. The old NOTE in config.k claiming otherwise was wrong for this version and has been corrected.
- Denied servers' MCP `instructions` blocks are also dropped from the system prompt (`session/system.ts`), and denied subagents disappear from the `task` tool description (`tool/registry.ts`).
- Per-skill scoping: `permission: {"skill": {"<name>": "deny"}}` filters that skill from `<available_skills>`; string-form `"skill": "deny"` removes the whole section.
- **Bug found & fixed**: MCP tool keys are sanitized (`[^a-zA-Z0-9_-]` → `_`, `mcp/catalog.ts`), so permission patterns built from raw multi-word server names ("Chrome DevTools*", "Home Assistant*") never matched — neither for context stripping nor execution gating. `_deny_all_mcp`/`_mcp_only` now sanitize names.

## Results

| agent | tools in request | tools JSON | system | request | ~tokens (bytes/4) |
|---|---|---|---|---|---|
| build (baseline, all MCPs) | 150 (137 MCP) | 143.0 KB | 44.8 KB | 182.5 KB | ~46,700 |
| local (deny all MCP + edit + skill) | 10 | 18.9 KB | 14.2 KB | 33.3 KB | ~8,500 |
| local — router-only retune (2026-07-22) | 2 | 6.9 KB | 14.5 KB | 21.8 KB | ~5,600 |
| local-pm (Backlog only + deny edit/skill) | 28 (20 MCP) | 29.4 KB | 13.4 KB | 42.0 KB | ~10,700 |
| local-dev (deny all MCP) | 11 | 15.7 KB | 37.6 KB | 53.7 KB | ~13,700 |

- (a) **Per-agent `permission: deny` reduces context tokens: CONFIRMED** — 71–82% request-size reduction vs the build baseline. The scoped rosters contained exactly the expected tools (local-pm: builtins + 20 Backlog tools; local-dev: 11 builtins, zero MCP).
- (b) **Host-level MCP exclusion reduces context: CONFIRMED trivially** — excluded servers (Obsidian, Home Assistant) cannot appear in any request; unconnected/failed servers' tools were also absent from the build baseline.
- **Router-only retune of `local` (measured 2026-07-22, opencode 1.18.4).** The original `local` roster was `glob, grep, read, webfetch, task, todowrite, list_mcp_resources, read_mcp_resource, list_mcp_resource_templates`. The three `*_mcp_resource*` tools ship regardless of `_deny_all_mcp` and are dead weight once every server is denied; `read/grep/glob/webfetch` contradict the agent's own "route discovery to `explore`" instruction. Denying all seven leaves `task` + `todowrite`: **9 → 2 tools, 14.0 → 6.9 KB of tool JSON, request 29.1 → 21.8 KB (−23%)**. Tool ids were taken from a captured request, not guessed — see the sanitization bug above for why that matters.
- **The system prompt is now the larger half of `local`'s footprint** (14.5 KB of a 21.8 KB request). Further reduction has to come from opencode's base prompt, not from tool scoping.
- Harness note: LM Studio normally holds 127.0.0.1:1234. To measure without stopping it, copy the deployed `~/.config/opencode/opencode.json`, repoint `provider.lmstudio.options.baseURL` at a free port, run the capture script on that port, and pass the copy via `OPENCODE_CONFIG`.
- The captured system prompts contained the new agent prompt-file headers, confirming the `{file:~/.config/opencode/prompt/agents/*.md}` refs resolve.

## Recommendation

**Keep the per-agent permission scoping — it is load-bearing for the local Qwen 3.5 lane.** The unscoped baseline (~47k est. tokens before any work) would not even fit a 32k local context window; the scoped local agents start at ~8.5–13.7k. Keep host-level exclusion for servers that should never spawn. The CLI-first decision for local agents (deny Jujutsu/GitHub MCP, use `jj`/`git` via bash) removes ~120 tool schemas per request; revisit only if a scoped agent demonstrably struggles with CLI VCS.
