---
id: TASK-3
title: Audit remaining bridge-backed Nushell completions
status: To Do
assignee: []
created_date: '2026-03-09 13:57'
labels: []
dependencies: []
references:
  - shared/completions.toml
  - carapace/bridges.yaml
  - nushell/config.nu
  - nushell/completions
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Identify which managed CLI tools still rely on bridge-based Nushell completions and verify that each one returns useful live suggestions so shell completion remains dependable as more tools are installed.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Each bridge-backed CLI currently managed in the shared completion config is checked through the deployed Nushell startup path when available locally.
- [ ] #2 Any bridge-backed CLI that still returns no useful completions is documented with its failure mode and a recommended fix path.
- [ ] #3 The shared completion setup is updated only for tools that need intervention, without regressing the working `acli` and `backlog` custom completers.
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Config is deployed using Dotter. If `--force` is required
- [ ] #2 back up the previous versions.
- [ ] #3 Validate results in relevant tool(s). If its a CLI tool
- [ ] #4 try in both `zsh` and `nu`.
<!-- DOD:END -->
