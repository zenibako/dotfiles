---
id: TASK-11
title: Optimize zsh shell startup time from ~1.4s to <100ms
status: In Progress
assignee: []
created_date: '2026-06-08 22:25'
labels:
  - performance
  - shell
  - zsh
  - dotfiles
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Apply terminal startup optimizations from the article https://mijndertstuij.nl/posts/life-is-too-short-for-a-slow-terminal/. Current startup time is ~1.4s, target is <100ms.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 zsh startup time measured under 100ms using `time zsh -i -c exit`
- [ ] #2 compinit uses 24h cache (`compinit -C`) instead of full scan every startup
- [ ] #3 nvm is lazy-loaded (not sourced eagerly on every shell)
- [ ] #4 oh-my-zsh framework overhead is reduced or eliminated
- [ ] #5 Shared completions regeneration only runs when completions.toml changes
- [ ] #6 All changes deployed via dotter and tested in a fresh shell
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Config is deployed using Dotter. If `--force` is required, back up the previous versions.
- [ ] #2 Validate results in relevant tool(s). If it's a CLI tool, try in both `zsh` and `nu`.
<!-- DOD:END -->
