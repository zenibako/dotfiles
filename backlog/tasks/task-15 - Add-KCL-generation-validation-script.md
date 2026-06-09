---
id: TASK-15
title: Add KCL generation validation script
status: To Do
assignee: []
created_date: '2026-06-09 12:53'
labels:
  - testing
  - kcl
dependencies: []
priority: high
ordinal: 5000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create a validation script that runs after KCL generation to ensure all generated configs parse correctly before deployment. This prevents broken configs from being deployed.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Validation script runs KCL + Python converter
- [ ] #2 Checks all generated TOML files parse correctly
- [ ] #3 Checks template files have valid structure
- [ ] #4 Can be run standalone or integrated into pre_deploy
- [ ] #5 Fails fast with clear error messages
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Config is deployed using Dotter. If `--force` is required, back up the previous versions.
- [ ] #2 Validate results in relevant tool(s). If it's a CLI tool, try in both `zsh` and `nu`.
<!-- DOD:END -->
