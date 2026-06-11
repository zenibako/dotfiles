---
id: TASK-16
title: 'Restructure KCL-Python pipeline: generic converter + move domain logic to KCL'
status: Done
assignee: []
created_date: '2026-06-11 02:40'
updated_date: '2026-06-11 02:54'
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

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Restructured KCL-Python pipeline to simplify architecture and add ruff linting:

## Changes

### KCL changes (domain logic moved from Python):
- **src/_shared/schemas.k**: Added `EnvSection` schema for structured env sections
- **src/env.k**: Restructured to emit sectioned env data with `sections` field (no more hardcoded Python lists)
- **src/tmux.k**: Now emits complete `tmux.conf` string via `file.write()`, with proper `${...}` escaping
- **src/main.k**: Directly writes text files (ghostty, gitconfig, pnpm/rc, tmux.conf) via `file.write()`. Emits metadata JSON files for env, completions, and packages to drive Python generically.

### Python simplification:
- **`.dotter/scripts/generate_from_kcl.py`**: Rewritten from 504 lines to 348 lines (~30% reduction). Now a data-driven converter that reads metadata from JSON and writes files based on type (TOML, template, text, env, completions, packages). All domain-specific hardcoding removed.

### Ruff linting:
- **`.dotter/scripts/.ruff.toml`**: Added ruff configuration with py39 target, E/F/I/N/W/UP/B/C4/SIM rules
- Fixed all ruff issues in Python scripts (import sorting, simplified conditionals, removed unnecessary mode args)

### Pipeline:
- KCL writes text files directly via `file.write()`
- KCL writes metadata JSON for structured data
- Python reads metadata and writes TOML/structured files via tomli_w
- All 13 validation checks pass
- ruff checks pass clean
<!-- SECTION:FINAL_SUMMARY:END -->
