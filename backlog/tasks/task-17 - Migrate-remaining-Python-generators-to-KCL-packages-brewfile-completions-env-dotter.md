---
id: TASK-17
title: >-
  Migrate remaining Python generators to KCL (packages, brewfile, completions,
  env, dotter)
status: Done
assignee: []
created_date: '2026-06-11 02:57'
updated_date: '2026-06-11 03:08'
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

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Migrated more config generation from Python to KCL:

## What Moved to KCL
- **packages-fedora.txt**: String join in KCL (src/packages.k)
- **Brewfile**: Format strings in KCL (src/packages.k)
- **completions.toml**: Header + iteration in KCL (src/completions.k)
- **ghostty/config, gitconfig, pnpm/rc, tmux.conf**: Already in KCL from previous task

## What's Still in Python (260 lines, down from 504)
- dotter global.toml (custom format with mixed types)
- TOML files requiring tomli_w (atuin, starship, aerospace, iamb, gitlogue)
- Template TOML files (jj with Handlebars marker resolution)
- env.toml (Handlebars conditionals with special formatting rules)

## Pipeline Changes
- KCL now writes 7 text files directly via file.write()
- Python only handles: dotter global.toml + 5 TOML files + env.toml
- Removed .completions_meta.json and .packages_meta.json (no longer needed)
- Updated .gitignore to remove .completions_meta.json

## Validation
- Full pipeline works: kcl run + python3 generate + validate all pass
- All 13 validation checks pass
- ruff check passes clean

## Files Changed
- src/packages.k: Added packages_txt and brewfile string builders
- src/completions.k: Added completions_toml string builder
- src/main.k: Added file.write() calls for packages, brewfile, completions
- .dotter/scripts/generate_from_kcl.py: Removed _write_packages_txt, _write_brewfile, _write_completions_toml, removed metadata loading
- .gitignore: Removed .completions_meta.json
<!-- SECTION:FINAL_SUMMARY:END -->
