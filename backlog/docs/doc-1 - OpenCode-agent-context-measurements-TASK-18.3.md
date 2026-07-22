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
| local — router-only retune (2026-07-22, current) | 2 | 7.0 KB | 15.3 KB | 22.7 KB | ~5,769 |
| local — PM merged in (2026-07-22) — REVERTED, see below | 28 (20 MCP) | 30.4 KB | 15.7 KB | 45.2 KB | ~11,306 |
| local-pm (Backlog only + deny edit/skill) — REMOVED | 28 (20 MCP) | 29.4 KB | 13.4 KB | 42.0 KB | ~10,700 |
| explore + read-only Backlog slice (2026-07-22, current) | 14 (6 MCP) | — | — | — | ~7,377 |
| local-pm — write-only Backlog slice (2026-07-22, current) | 12 (5 MCP) | — | — | — | ~7,818 |
| local-dev (deny all MCP) | 11 | 15.7 KB | 37.6 KB | 53.7 KB | ~13,700 |

- (a) **Per-agent `permission: deny` reduces context tokens: CONFIRMED** — 71–82% request-size reduction vs the build baseline. The scoped rosters contained exactly the expected tools (explore: builtins + 6 Backlog read tools; local-dev: 11 builtins, zero MCP).
- (b) **Host-level MCP exclusion reduces context: CONFIRMED trivially** — excluded servers (Obsidian, Home Assistant) cannot appear in any request; unconnected/failed servers' tools were also absent from the build baseline.
- **Router-only retune of `local` (measured 2026-07-22, opencode 1.18.4).** The original `local` roster was `glob, grep, read, webfetch, task, todowrite, list_mcp_resources, read_mcp_resource, list_mcp_resource_templates`. The three `*_mcp_resource*` tools ship regardless of `_deny_all_mcp` and are dead weight once every server is denied; `read/grep/glob/webfetch` contradict the agent's own "route discovery to `explore`" instruction. Denying all seven leaves `task` + `todowrite`: **9 → 2 tools, 14.0 → 6.9 KB of tool JSON, request 29.1 → 21.8 KB (−23%)**. Tool ids were taken from a captured request, not guessed — see the sanitization bug above for why that matters.
- **The system prompt is now the larger half of `local`'s footprint** (14.5 KB of a 21.8 KB request). Further reduction has to come from opencode's base prompt, not from tool scoping.
- **`local-pm` removed; Backlog moved to `explore`, NOT to `local` (2026-07-22, opencode 1.18.4).** The `local-pm` subagent only ever wrapped the Backlog MCP, so it was deleted. The obvious home for Backlog was the orchestrator itself — that was built and measured, and **it does not fit the 27B**, so it was reverted and the tools went to `explore` instead.

  **The 27B budget for `local` (why the router roster is fixed at 2 tools).** Fitted window 11,776 tokens on this machine (`src/launchd/iogpu_wired_limit.k`), minus `compaction.reserved` 2,048 → **9,728 usable**. The floor before any optional tool:

  | component | ~tokens | removable? |
  |---|---|---|
  | opencode base + `local.md` system prompt | ~3,920 | no — opencode's own |
  | `task` (delegation) | ~1,064 | no — it *is* the router |
  | `todowrite` | ~682 | only by giving up pipeline tracking |
  | **floor** | **~5,666** | leaves **~4,060** to work in |

  Measured `local` at exactly this roster: **5,685 est. tokens** — the prediction held.

  **Per-tool schema bytes (captured 2026-07-22; `tool_bytes` field in the harness).** Backlog's 20 tools are ~4,440 est. tokens, but wildly uneven — the write tools carry the weight:

  | tool | ~tokens | | tool | ~tokens |
  |---|---|---|---|---|
  | `task_edit` | 1,351 | | `task_complete` | 76 |
  | `task_create` | 747 | | `task_view` | 68 |
  | `task_search` | 302 | | `task_archive` | 67 |
  | `task_list` | 299 | | 5 × `document_*` | 578 total |
  | `read`/`grep`/`glob` | 1,030 | | 5 × `milestone_*` | 644 total |

  So no trim of the merged design fits: read-only `task_list`/`task_search`/`task_view` (~669) alone drops working room to ~3,393 — the same budget that had `explore` looping on compaction. Adding `task_edit` (needed to move a task to In Progress) drops it to ~937. The full server overruns the window outright (~11,306 overhead vs 9,728 usable, i.e. negative).
  - **Resolution.** `local` stays the 2-tool router on the 27B. `explore` (pinned to the 9B, 32k) gets `_explore_backlog_read_tools` — the six non-mutating Backlog tools, ~911 tokens, measured at **7,377** total. The orchestrator reaches Backlog through a `task` call, which is what it already does for all discovery.
  - **Backlog reads and writes are split across two subagents.** `explore` holds the six non-mutating tools (triage rides along with the discovery it already does); `local-pm` was restored holding only `task_search`/`task_view`/`task_create`/`task_edit`/`task_complete` (~7,818 est. tokens, 12 tools). The split keeps `task_edit` — the single most expensive schema in the local lane at ~1,351 tokens, 30% of the whole Backlog server — out of the agent invoked on every discovery question, and makes task mutation an explicitly spawned step rather than a side effect of answering "what should I work on?".
  - **Cost of restoring a subagent to `local`: ~84 est. tokens.** Adding `local-pm` back grows the `task` tool schema (opencode enumerates subagents in its description, `tool/registry.ts`): 4,258 → 4,358 bytes, request ~5,685 → **~5,769**. Working room on the 27B drops ~4,060 → ~3,959. Worth knowing before adding further subagents — each one taxes the router, which is the agent with the least room.
  - **The real lever is the model, not the roster.** The 27B is memory-bound: trimming tools cannot buy 5,600 tokens, but a smaller quant can. Raising `iogpu.wired_limit_mb` cannot either — reaching a comfortable merged-`local` budget needs ~22.5 GiB wired, leaving macOS 2 GiB, which panics rather than slows.

## 3-bit 27B quant (probed 2026-07-22)

`leonsarmiento/Qwen3.6-27B-3bit-mlx` replaced the 4-bit **under the same LM Studio identifier** (`qwen3.6-27b`), so there is one model entry, not two. Confirm which is resident via `curl -s localhost:1234/api/v0/models` — it reports `publisher` and `quantization`.

**This model has no auto-fit, which changes the whole failure model.** It loads through `mlx_engine`'s `batched_model_kit`; the 4-bit used the plain MLX path. The batched path emits no `[context_fit]` line and never clamps context to what fits — confirmed by the log, where the last `context_fit` entry is 09:05 (the 4-bit) and none appear for the 3-bit loads from 19:18 onward. So an over-long prompt does not produce "the number of tokens to keep from the initial prompt is greater than the context length". It hard-crashes the Python backend:

```
[METAL] Command buffer execution failed: Insufficient Memory
  (00000008:kIOGPUCommandBufferCallbackErrorOutOfMemory)
Fatal Python error: Aborted
  mlx_lm/generate.py line 1161 in prompt
```

**There is no `fitted=` to read; measurement is the only source of truth.** Probed 2026-07-22 (single-shot, temp 0):

| prompt tokens | result |
|---|---|
| 9,016 | OK |
| 22,516 | OK |
| ~31,500 | crashed at **78% of prompt processing** — i.e. ~24,600 tokens of KV allocated |

That 78% figure is the useful one: it locates the wall at **~24,600 tokens** from a single crash, where bisecting would have cost several. When a crash log reports progress, read the progress.

**Two things the earlier arithmetic got wrong.** It predicted ~32,900 from 12.1 GB of safetensors (≈11.27 GiB) at the 4-bit's 182.5 KiB/token. File size is not resident size, and a per-token KV cost carries across neither quantizations nor engine paths. Corroborating signals that were visible and under-weighted: LM Studio reports this model's `quantization` as `4bit` despite the name, and the repo ships a 128 kB `config.json` — mixed per-layer quant, not uniform 3-bit.

**Also corrected:** `safe_ceiling` is `working_set - 3.00 GiB` (a flat reserve, per the 4-bit's `context_fit` line), not the 0.85 factor used in the earlier projection — the two coincided at 20 GiB.

`limit.context` is set to **20,480**, ~4,000 below the measured wall. The margin is deliberate: the failure is a process death costing a manual reload, not a recoverable error, and KV cost varies with content while other apps compete for the same GPU budget. That still hosts every local agent with real room (local ~12,700 / explore ~11,100 / local-pm ~10,600 / **local-dev ~9,200**) — including local-dev, which the 4-bit's 11,776-token window could not host at all. The read/write Backlog split is therefore no longer forced by the budget; it is kept on its own merits.

**LM Studio substitutes models silently — this invalidates per-agent model pins.** It serves whatever model is *resident* regardless of the request's `model` field. With only the 27B loaded, a request saying `"model": "qwen3.5-9b"` is answered by the 27B; the log shows `[qwen3.6-27b] Running chat completion` with no error or warning.

This crashed a live session on 2026-07-22. The chain:

1. Only the 27B was loaded.
2. `explore` is pinned to `qwen3.5-9b` → actually ran on the 27B.
3. opencode budgeted the session against the **9B's** declared 32,768 limit.
4. The 27B's hardware wall is **~24,600**.
5. `explore` ran `glob **/*` over a repo then read five files; context crossed the wall → Metal OOM → backend death mid-task.

**Mitigation: every lmstudio model entry carries the smallest safe limit across the models that might answer** (currently 20,480 for both). Raising one in isolation reintroduces the crash. Per-agent `model` pins remain correct as declarations of intent, but they cannot be relied on for capacity planning — the ceiling is set by whichever model is loaded, not the one requested.

Co-residency would fix the substitution properly but does not fit: the 27B 3-bit (11 GB) plus the 8-bit 9B (9.7 GB) is ~20 GiB of weights against a 20 GiB wired limit, before any KV cache. The 4-bit 9B (5.6 GB) would leave ~4.6 GiB for KV across both — possible, but only with both capped well below their windows.

**Action outside version control:**

- Harness note: LM Studio normally holds 127.0.0.1:1234. To measure without stopping it, copy the deployed `~/.config/opencode/opencode.json`, repoint `provider.lmstudio.options.baseURL` at a free port, run the capture script on that port, and pass the copy via `OPENCODE_CONFIG`.
- **`OPENCODE_CONFIG` does NOT isolate permissions** (learned the hard way, 2026-07-22). opencode still loads and validates `~/.config/opencode/opencode.json` and merges it, so the *union* of both configs' `permission` rules applies — a tool the candidate config re-allows stays stripped if the deployed config still denies it. The first measurement of the merged `local` reported 22 tools instead of 28 for exactly this reason. To measure a permission change before deploying it, back up the deployed file, copy the candidate over it, run, and restore (use a shell `trap` — a `timeout` that fires will otherwise leave the candidate in place).
- The captured system prompts contained the new agent prompt-file headers, confirming the `{file:~/.config/opencode/prompt/agents/*.md}` refs resolve.

## Recommendation

**Keep the per-agent permission scoping — it is load-bearing for the local Qwen 3.5 lane.** The unscoped baseline (~47k est. tokens before any work) would not even fit a 32k local context window; the scoped local agents start at ~8.5–13.7k. Keep host-level exclusion for servers that should never spawn. The CLI-first decision for local agents (deny Jujutsu/GitHub MCP, use `jj`/`git` via bash) removes ~120 tool schemas per request; revisit only if a scoped agent demonstrably struggles with CLI VCS.
