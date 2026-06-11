---
id: TASK-17
title: >-
  Migrate remaining Python generators to KCL (packages, brewfile, completions,
  env, dotter)
status: In Progress
assignee: []
created_date: '2026-06-11 02:57'
labels:
  - refactor
  - kcl
  - python
  - dotfiles
dependencies: []
modified_files:
  - src/main.k
  - src/packages.k
  - src/completions.k
  - src/env.k
  - src/profiles.k
  - src/_shared/schemas.k
  - .dotter/scripts/generate_from_kcl.py
ordinal: 7000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Continue the KCL-Python pipeline restructure by migrating remaining text-format generators from Python to KCL. Python will be left with only TOML serialization (tomli_w) and template marker resolution.

Files to migrate to KCL:
1. packages-fedora.txt (string join)
2. Brewfile (trivial formatting)
3. completions.toml (header + iteration)
4. env.toml (Handlebars conditionals as strings)
5. dotter global.toml (complex but worth doing)

After this, Python script shrinks to ~100 lines, focused on tomli_w only.

Target files:
- src/main.k (add file.write() calls)
- src/packages.k (add Brewfile string builder)
- src/completions.k (add completions.toml string builder)
- src/env.k (add env.toml string builder)
- src/profiles.k (add dotter global.toml string builder)
- .dotter/scripts/generate_from_kcl.py (remove migrated functions)
- .dotter/scripts/validate_generated.py (update paths if needed)
<!-- SECTION:DESCRIPTION:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Config is deployed using Dotter. If `--force` is required, back up the previous versions.
- [ ] #2 Validate results in relevant tool(s). If it's a CLI tool, try in both `zsh` and `nu`.
<!-- DOD:END -->
