---
id: TASK-2
title: Fix backlog Nushell completions with direct completion shim
status: Done
assignee: []
created_date: '2026-03-09 13:35'
updated_date: '2026-03-09 13:40'
labels: []
dependencies: []
references:
  - shared/completions.toml
  - nushell/config.nu
  - nushell/completions
  - carapace/bridges.yaml
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Make Nushell load working completions for the Backlog CLI by using its native internal completion API instead of the current bridge path that returns no results.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 `backlog` completions return command suggestions in Nushell through the deployed startup path.
- [x] #2 The shared completion configuration reflects the direct Nushell completion mechanism used for `backlog`.
- [x] #3 The fix does not regress the existing `acli` custom completion path.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add a dedicated Nushell completion script for `backlog` that calls `backlog completion __complete <line> <point>` and converts the returned suggestions into Nushell completion records.
2. Update the shared completion generator and Nushell external completer wrapper so `backlog` uses the direct completion path instead of the failing bridge.
3. Verify the deployed startup path returns completions for `backlog` while preserving the working `acli` behavior.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Tested current managed tools through the deployed Nushell external completer. `dotter`, `gog`, `pnpm`, and `sf` already returned useful results, while `backlog` returned `null` and was the clearest next candidate for a direct shim.

Confirmed `backlog` exposes a native internal API via `backlog completion __complete <line> <point>`, returning subcommands and task IDs suitable for conversion into Nushell completion records.

Added `nushell/completions/backlog.nu` with `export def backlog-completer` that calls the internal completion API and maps output into Nushell completion values.

Updated `shared/completions.toml` so `backlog` now generates its Nushell completion file from the dedicated script instead of relying on the bridge path.

Updated `nushell/config.nu` to capture explicit closures for both `acli` and `backlog` custom completers before wrapping the external completer, which resolved command lookup issues inside the stored config closure.

Verified the full deployed startup path returns live completions for `backlog task`, `backlog task view`, and still preserves the working `acli jira workitem` completions.
<!-- SECTION:NOTES:END -->
