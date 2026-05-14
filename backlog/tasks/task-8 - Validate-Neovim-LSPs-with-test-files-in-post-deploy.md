---
id: TASK-8
title: Validate Neovim LSPs with test files in post-deploy
status: In Progress
assignee: []
created_date: '2026-05-14 00:27'
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
- [ ] #1 Can detect which LSPs are enabled from the deployed nvim config
- [ ] #2 Creates minimal test files for each enabled LSP filetype
- [ ] #3 Opens each test file in nvim --headless and verifies LSP client attaches
- [ ] #4 Reports which LSPs fail to attach
- [ ] #5 Does not block deploy on LSP failures (warning only, since servers may not be installed)
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Config is deployed using Dotter. If `--force` is required, back up the previous versions.
- [ ] #2 Validate results in relevant tool(s). If it's a CLI tool, try in both `zsh` and `nu`.
<!-- DOD:END -->
