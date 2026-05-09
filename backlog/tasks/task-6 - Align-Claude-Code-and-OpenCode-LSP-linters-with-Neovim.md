---
id: TASK-6
title: Align Claude Code and OpenCode LSP/linters with Neovim
status: In Progress
assignee: []
created_date: '2026-05-09 01:12'
labels:
  - config
  - lsp
  - claude-code
  - opencode
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Ensure both OpenCode and Claude Code are configured to use the same language servers and formatters/linters as the Neovim setup. Currently several LSPs present in Neovim (basedpyright, gopls, html, jsonls, lua_ls, yamlls, gitlab_ci_ls, terraformls, jinja-lsp, ts_ls) are missing or only partially configured in the AI coding tools.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 OpenCode lsp config includes all Neovim LSPs: basedpyright, gopls, html, jsonls, lua_ls, yamlls, gitlab_ci_ls, terraformls, jinja-lsp, ts_ls
- [ ] #2 Claude Code enabledPlugins include all available matching LSP plugins for Neovim servers
- [ ] #3 Profile-conditional entries (work/personal) are preserved and correctly gated
- [ ] #4 Configuration files deploy correctly via dotter with no syntax errors
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Config is deployed using Dotter. If `--force` is required, back up the previous versions.
- [ ] #2 Validate results in relevant tool(s). If it's a CLI tool, try in both `zsh` and `nu`.
<!-- DOD:END -->
