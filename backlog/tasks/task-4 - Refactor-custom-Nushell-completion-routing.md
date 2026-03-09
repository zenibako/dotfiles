---
id: TASK-4
title: Refactor custom Nushell completion routing
status: To Do
assignee: []
created_date: '2026-03-09 13:59'
updated_date: '2026-03-09 14:05'
labels: []
dependencies: []
references:
  - nushell/config.nu
  - nushell/completions
  - shared/completions.toml
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Reduce maintenance overhead in the Nushell completion wrapper by replacing the current hardcoded custom-completer routing with a cleaner pattern that scales as more direct completion shims are added.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The Nushell external completer wrapper supports multiple custom completers through a maintainable structure instead of repeated special cases.
- [ ] #2 The refactor preserves the existing live completion behavior for `acli` and `backlog`.
- [ ] #3 The structure makes it straightforward to add future direct Nushell completion shims without reworking the wrapper logic.
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Config is deployed using Dotter. If `--force` is required
- [ ] #2 back up the previous versions.
- [ ] #3 Validate results in relevant tool(s). If its a CLI tool
- [ ] #4 try in both `zsh` and `nu`.
<!-- DOD:END -->
