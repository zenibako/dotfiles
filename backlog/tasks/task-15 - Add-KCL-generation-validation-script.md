---
id: TASK-15
title: Add KCL generation validation script
status: Done
assignee: []
created_date: '2026-06-09 12:53'
updated_date: '2026-06-13 20:17'
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
- [x] #1 Validation script runs KCL + Python converter
- [x] #2 Checks all generated TOML files parse correctly
- [x] #3 Checks template files have valid structure
- [x] #4 Can be run standalone or integrated into pre_deploy
- [x] #5 Fails fast with clear error messages
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Create validate_generated.py script that:
   - Runs KCL generation
   - Parses all generated TOML files with tomllib/tomli
   - Checks template files for valid structure
   - Verifies expected files exist
2. Add to pre_deploy.sh to run after generation
3. Test with current configs
4. Commit changes
<!-- SECTION:PLAN:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Validation script `validate_generated.py` already existed and was integrated into `pre_deploy.sh`. Updated it to validate all newer KCL-generated files: opencode.jsonc, claude_desktop_config.json, claude-code/settings.json, and zshenv. All checks pass (TOML parsing, template Handlebars balance, required placeholders). Script runs standalone via `python3 .dotter/scripts/validate_generated.py` and is automatically called by `pre_deploy.sh` after KCL generation. Fails fast with clear error messages.
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Config is deployed using Dotter. If `--force` is required, back up the previous versions.
- [ ] #2 Validate results in relevant tool(s). If it's a CLI tool, try in both `zsh` and `nu`.
<!-- DOD:END -->
