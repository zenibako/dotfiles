---
id: TASK-13
title: Migrate remaining configs and simple shell scripts to KCL
status: In Progress
assignee: []
created_date: '2026-06-09 11:34'
labels:
  - refactor
  - kcl
dependencies: []
priority: medium
ordinal: 3000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Continue KCL migration for remaining Tier 1 (templates: gitconfig, ghostty/config), Tier 2 (static: pnpm/rc, git/commit-template), and simple shell scripts (lwc-lsp-wrapper.sh, prepare-commit-msg, waybar/reload.sh). These are the easiest remaining configs to migrate while maintaining functionality.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 gitconfig migrated to KCL with template placeholders
- [ ] #2 ghostty/config migrated to KCL with template placeholders
- [ ] #3 pnpm/rc migrated to KCL as static config
- [ ] #4 git/commit-template migrated to KCL as static template
- [ ] #5 lwc-lsp-wrapper.sh migrated to KCL as static script
- [ ] #6 prepare-commit-msg migrated to KCL (static or parameterized)
- [ ] #7 waybar/reload.sh migrated to KCL as static script
- [ ] #8 All migrated configs pass dotter deploy dry-run
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Config is deployed using Dotter. If `--force` is required, back up the previous versions.
- [ ] #2 Validate results in relevant tool(s). If it's a CLI tool, try in both `zsh` and `nu`.
<!-- DOD:END -->
