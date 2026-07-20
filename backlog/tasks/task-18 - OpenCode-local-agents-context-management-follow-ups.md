---
id: TASK-18
title: 'OpenCode local agents: context-management follow-ups'
status: In Progress
assignee: []
created_date: '2026-07-20 14:32'
updated_date: '2026-07-20 15:22'
labels:
  - opencode
  - context-management
dependencies: []
references:
  - src/opencode/config.k
  - src/opencode/prompt/agents/
  - src/_shared/mcp.k
  - 'https://github.com/Sanix-Darker/radar/pull/16'
priority: medium
type: feature
ordinal: 8000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Umbrella for the remaining work after a context-management pass on the global OpenCode agent setup (deployed from this dotfiles repo to ~/.config/opencode).

Background / what already shipped (on main):
- Agent prompts were externalized from src/opencode/config.k into src/opencode/prompt/agents/*.md, referenced via OpenCode's `{file:~/.config/opencode/prompt/agents/<name>.md}` syntax (see the `_agent_prompt` helper in config.k).
- Obsidian and Home Assistant MCP servers were excluded from the host config (see `_MCP_HOST_EXCLUDED` in src/_shared/mcp.k) and moved to per-project `.opencode/opencode.json` via `{env:}` (~/Personal, ~/Projects/home-assistant).
- Per-agent MCP access is scoped with `permission` wildcards (helpers `_deny_all_mcp` / `_mcp_only` in config.k), because OpenCode ignores a per-agent `mcp` field.
- A `radar` code-navigation CLI was integrated (guarded), plus AGENTS.md navigation guidance and routing discovery through the built-in `explore` subagent.

The agent roster lives in src/opencode/config.k (`_agent` dict): primary agents build/plan/local; subagents tester/reviewer/local-pm/local-dev. This umbrella tracks completing the roster and validating that the context reductions are real. See subtasks for the concrete deliverables.
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Config is deployed using Dotter. If `--force` is required, back up the previous versions.
- [ ] #2 Validate results in relevant tool(s). If it's a CLI tool, try in both `zsh` and `nu`.
<!-- DOD:END -->
