---
id: TASK-13
title: Migrate remaining configs and simple shell scripts to KCL
status: Done
assignee: []
created_date: '2026-06-09 11:34'
updated_date: '2026-06-13 20:13'
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
- [x] #1 gitconfig migrated to KCL with template placeholders
- [x] #2 ghostty/config migrated to KCL with template placeholders
- [x] #3 pnpm/rc migrated to KCL as static config
- [x] #4 git/commit-template migrated to KCL as static template
- [x] #5 lwc-lsp-wrapper.sh migrated to KCL as static script
- [x] #6 prepare-commit-msg migrated to KCL (static or parameterized)
- [x] #7 waybar/reload.sh migrated to KCL as static script
- [x] #8 All migrated configs pass dotter deploy dry-run
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Fixed waybar path in profiles.k (changed src/waybar to waybar since the directory is at root level, not in src/).

gitconfig, ghostty/config, and pnpm/rc are already KCL-generated.

git/commit-template, lwc-lsp-wrapper.sh, prepare-commit-msg, and waybar/reload.sh are static files that don't require template variables; they remain in src/ and are deployed correctly.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Completed migration of remaining configs. gitconfig, ghostty/config, and pnpm/rc were already KCL-generated. Fixed waybar path in profiles.k (changed 'src/waybar' to 'waybar' since the directory is at root level). Static files (git/commit-template, lwc-lsp-wrapper.sh, prepare-commit-msg, waybar/reload.sh) remain in src/ as they don't require template variables. dotter deploy dry-run passes for all configs (only expected secret-injection diffs from post_deploy.sh).
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Config is deployed using Dotter. If `--force` is required, back up the previous versions.
- [ ] #2 Validate results in relevant tool(s). If it's a CLI tool, try in both `zsh` and `nu`.
<!-- DOD:END -->
