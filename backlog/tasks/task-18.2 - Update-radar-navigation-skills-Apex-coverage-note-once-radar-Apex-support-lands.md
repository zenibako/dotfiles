---
id: TASK-18.2
title: >-
  Update radar-navigation skill's Apex coverage note once radar Apex support
  lands
status: To Do
assignee: []
created_date: '2026-07-20 14:33'
labels:
  - opencode
  - context-management
dependencies: []
references:
  - src/opencode/skills/radar-navigation/SKILL.md
  - 'https://github.com/Sanix-Darker/radar/pull/16'
parent_task_id: TASK-18
priority: low
type: docs
ordinal: 10000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The `radar-navigation` skill (src/opencode/skills/radar-navigation/SKILL.md) has a "Language coverage" section that lists Apex (plus KCL, Lua, etc.) as NOT parsed by radar and warns agents to treat radar anchors as weak for those. That is accurate for radar upstream v0.3.0.

Apex support was subsequently added to radar in a draft PR (external dependency): https://github.com/Sanix-Darker/radar/pull/16 . Once that support is available in the radar the user actually runs (PR merged upstream, or the local add-apex build treated as canonical), the skill's caveat becomes stale and should be corrected.

External blocker: this task should not be started until radar Apex support is merged/released upstream (or a deliberate decision is made to treat the local build as the reference).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 When radar's Apex support is available in the running radar, the skill's Language-coverage section lists Apex as supported and removes it from the unsupported caveat
- [ ] #2 The caveat still accurately lists the remaining unsupported languages (e.g., KCL, Lua)
- [ ] #3 The skill still guards on `command -v radar` and does not otherwise change behavior
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Config is deployed using Dotter. If `--force` is required, back up the previous versions.
- [ ] #2 Validate results in relevant tool(s). If it's a CLI tool, try in both `zsh` and `nu`.
<!-- DOD:END -->
