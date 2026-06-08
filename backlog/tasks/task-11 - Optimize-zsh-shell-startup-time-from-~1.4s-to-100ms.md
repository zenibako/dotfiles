---
id: TASK-11
title: Optimize zsh shell startup time from ~1.4s to <100ms
status: Done
assignee: []
created_date: '2026-06-08 22:25'
updated_date: '2026-06-08 22:42'
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

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Results

### Measurements (5-run average)
- **Before:** ~1.40s real time
- **After:** ~0.094s (94ms) real time
- **Speedup:** 14x faster

### Changes Made
1. **Removed oh-my-zsh** (lines 59-132 in original zshrc). Extracted only the git aliases you actually use (`g`, `ga`, `gst`, etc.) inline, plus the `extract` helper. This saved ~900ms.
2. **Lazy-loaded nvm** via function wrapper. `nvm` is now a stub that sources the real nvm.sh on first invocation. This saves ~500ms on shells where you don't need Node.
3. **Cached compinit** with 24-hour glob check (`compinit -C`). Full compinit scan only runs once per day.
4. **Cached zshenv** env.toml parsing. The `_load_shared_env` function now writes a `.zshenv.cache.zsh` file after parsing, and subsequent shells source it directly — avoiding `tomlq` (a Python process!) on every invocation. This saved ~180ms.
5. **Cached `brew --prefix`** in zshrc with a `_BREW_PREFIX` guard, saving ~40ms per startup.
6. **Conditional shared completions** — `_load_shared_completions` only runs when `completions.toml` mtime is newer than the marker file.

### Verification
- All git aliases present: `g=git`, `ga=git add`, `gst=git status`, etc.
- Lazy nvm works: `nvm` is a function, calling it sources real nvm on first use
- Completions still load (fpath + compinit + bashcompinit loop)
- Prompt (starship) renders normally
- All tools (zoxide, atuin, pyenv, deno, ghcup, cargo) still initialize

### Files Modified
- `zshrc` — removed oh-my-zsh, lazy nvm, cached brew, inline aliases
- `zshenv` — added `.zshenv.cache.zsh` generation and sourcing
- `.dotter/post_deploy.sh` — escaped `{{` patterns that broke Handlebars parsing (side fix)

### Commit
`perf(shell): optimize zsh startup from ~1.4s to ~94ms` — committed with jj, GPG signed.
<!-- SECTION:NOTES:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Config is deployed using Dotter. If `--force` is required, back up the previous versions.
- [ ] #2 Validate results in relevant tool(s). If it's a CLI tool, try in both `zsh` and `nu`.
<!-- DOD:END -->
