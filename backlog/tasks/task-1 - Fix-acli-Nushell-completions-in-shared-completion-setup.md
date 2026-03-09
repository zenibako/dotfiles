---
id: TASK-1
title: Fix acli Nushell completions in shared completion setup
status: Done
assignee: []
created_date: '2026-03-09 13:12'
updated_date: '2026-03-09 13:20'
labels: []
dependencies: []
references:
  - shared/completions.toml
  - carapace/bridges.yaml
  - nushell/env.nu
  - nushell/config.nu
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Make the shared shell completion setup load working Nushell completions for the Atlassian CLI so acli commands autocomplete consistently alongside the rest of the managed CLI tooling.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 `acli` completions are generated and loaded successfully in Nushell through the shared completion workflow.
- [x] #2 The shared completion configuration matches the completion mechanism actually used for `acli` in Nushell.
- [x] #3 Any agent-facing documentation affected by the completion behavior is updated to reflect the working setup.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add a dedicated Nushell completion script for `acli` that shells out to `acli __complete` and converts Cobra completion output into Nushell completion records.
2. Update the shared completion configuration so Nushell sources the dedicated `acli` completion script instead of relying on the broken carapace bridge path.
3. Verify the generated completion works for top-level and nested `acli` commands in Nushell, then update notes with the root cause and fix.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Investigated Nushell completion path and found `acli` has no native `completion nushell` output, while the existing carapace external completer returned `null` for `acli` even though `acli __complete` returned valid Cobra completions.

Added `nushell/completions/acli.nu` with a dedicated `acli-completer` that shells out to `acli __complete`, strips Cobra directives, and returns Nushell completion records.

Updated `shared/completions.toml` so the shared generator sources the dedicated `acli` Nushell completion file instead of relying on the broken carapace bridge.

Updated `nushell/config.nu` to wrap the existing external completer and route only `acli` spans through the dedicated completer path while preserving the previous fallback for other commands.

Verified the new completer returns expected suggestions for `acli` and `acli jira` in Nushell via `nu -c` tests.
<!-- SECTION:NOTES:END -->
