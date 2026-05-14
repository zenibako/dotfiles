---
id: TASK-8
title: Validate Neovim LSPs with test files in post-deploy
status: Done
assignee: []
created_date: '2026-05-14 00:27'
updated_date: '2026-05-14 01:07'
labels:
  - enhancement
  - neovim
  - lsp
  - dotter
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Currently post-deploy only checks Neovim startup (+qa!) and Lua syntax (luac -p). It does NOT verify that configured LSP servers actually start and attach to buffers. We need to add a validation step that opens a test file for each LSP filetype and confirms the LSP client attaches successfully.

LSP configs to validate (personal profile):
- gopls (go)
- basedpyright (python)
- lua_ls (lua)
- html (html)
- jsonls (json)
- yamlls (yaml)
- ts_ls (typescript) — personal profile
- cuelang (cue) — personal profile
- sourcekit (swift) — personal profile
- jinja-lsp (jinja) — personal profile

LSP configs to validate (work profile adds):
- apex-language-server (apex)
- gitlab_ci_ls (gitlab-ci)
- lwc_ls (lwc)
- terraformls (terraform)
- visualforce_ls (visualforce)
- cuelang (cue) — work profile too
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Can detect which LSPs are enabled from the deployed nvim config
- [x] #2 Creates minimal test files for each enabled LSP filetype
- [x] #3 Opens each test file in nvim --headless and verifies LSP client attaches
- [x] #4 Reports which LSPs fail to attach
- [x] #5 Does not block deploy on LSP failures (warning only, since servers may not be installed)
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
## Summary

Implemented LSP validation in the `dotter deploy` post-deploy hook. The new `validate_lsp.lua` script discovers all enabled LSPs via `vim.lsp._enabled_configs`, creates test buffers for each filetype, opens them in Neovim headless, and verifies the expected LSP client attaches.

### Changes Made

1. **New file**: `.dotter/scripts/validate_lsp.lua` — Standalone Lua script run inside nvim headless:
   - Discovers enabled LSPs via `vim.lsp._enabled_configs`
   - Checks binary availability before attempting attachment
   - Creates test files with proper content and root markers
   - Waits for the specific LSP client to attach (with 2s grace period + 15s timeout)
   - Handles function-based `cmd` wrappers (typescript-tools.nvim)
   - Supports name aliases (e.g. `cuelang → cue` in enable(), config key is `cue`)
   - Reports OK / WARN / SKIP with colored icons
   - Exits 0 always (warnings don't block deploy)

2. **Fixed nvim config bug**: `nvim/default/lua/config/lsp.lua`:
   - Changed `vim.lsp.enable("cuelang")` → `vim.lsp.enable("cue")` to match the actual nvim-lspconfig config key (`cue`). This was a latent bug: the LSP was silently never attaching because Neovim couldn't find a config named `cuelang`.

3. **Updated** `.dotter/post_deploy.sh`:
   - Added LSP validation step after Neovim startup test
   - Uses `perl` for ANSI stripping (macOS sed doesn't support hex escapes)
   - Captures stderr (where nvim `--headless` sends Lua `print()` output)
   - Filters out image.nvim terminal errors and null-ls diagnostics noise

### Results on current system (personal profile)

```
== LSP Validation Results ==
  ✓ basedpyright              basedpyright, jinja-lsp
  ✓ cue                       cue
  ✓ gopls                     gopls
  ⊘ html                      not installed: vscode-html-language-server
  ✓ jinja-lsp                 jinja-lsp
  ⊘ jsonls                    not installed: vscode-json-language-server
  ✓ lua_ls                    null-ls, lua_ls
  ✓ sourcekit                 sourcekit
  ✓ ts_ls                     null-ls, ts_ls
  ✓ typescript-tools          null-ls, ts_ls, typescript-tools
  ⊘ yamlls                    not installed: yaml-language-server
8 OK, 0 warnings, 3 skipped
```

3 skipped = language servers not installed (these are from `vscode-langservers-extracted` and `yaml-language-server` packages).
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Config is deployed using Dotter. If `--force` is required, back up the previous versions.
- [ ] #2 Validate results in relevant tool(s). If it's a CLI tool, try in both `zsh` and `nu`.
<!-- DOD:END -->
