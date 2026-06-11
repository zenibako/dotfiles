---
id: TASK-16
title: 'Restructure KCL-Python pipeline: generic converter + move domain logic to KCL'
status: In Progress
assignee: []
created_date: '2026-06-11 02:40'
labels:
  - refactor
  - kcl
  - python
  - dotfiles
dependencies: []
modified_files:
  - .dotter/scripts/generate_from_kcl.py
  - src/main.k
  - src/_shared/schemas.k
  - src/env.k
  - src/tmux.k
  - src/ghostty/main.k
  - src/pnpm/main.k
  - src/gitconfig/main.k
ordinal: 6000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The current `.dotter/scripts/generate_from_kcl.py` is 500+ lines with hardcoded domain logic (env var lists, tmux template reconstruction, custom TOML serializer). This violates the principle that KCL should be the single source of truth for config data.

This task restructures the pipeline so:
1. KCL emits complete text files (ghostty, tmux, gitconfig, pnpm/rc) via `file.write()`
2. KCL structures env data generically so Python just iterates
3. Python becomes a generic converter: reads metadata from JSON, writes TOML via tomli_w, writes text verbatim, resolves template markers
4. Add ruff for linting the Python scripts

Target: Python script shrinks from ~500 lines to ~150-200 lines.
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Config is deployed using Dotter. If `--force` is required, back up the previous versions.
- [ ] #2 Validate results in relevant tool(s). If it's a CLI tool, try in both `zsh` and `nu`.
<!-- DOD:END -->
