---
name: jj-fix-conflicts
description: "Resolve Jujutsu (jj) conflicts sequentially across a stacked branch — oldest conflicted revision first, preserving each commit's intent."
---

## Core Rule

Resolve conflicts **in commit order from oldest to newest conflicted revision**. Never start at the tip unless it is the only conflicted revision.

## Workflow

1. **Inspect the stack** — `jj status`, then `jj log` to identify all `(conflict)` change IDs in order.

2. **Understand before editing** — `jj show <change>` to see what that revision intended. Compare the conflicted file against the already-resolved descendant (if any) and the destination/base.

3. **Edit the oldest conflicted revision** — `jj edit <change-id>`. If a later resolved revision already has the right merged shape, restore that file into `@` then back out any changes belonging to later commits. Otherwise manually merge so this revision contains only destination-branch behavior + this revision's intended delta.

4. **Verify immediately** — confirm no conflict markers remain, then `jj status` to confirm the revision is no longer conflicted.

5. **Move to the next** — `jj edit <next-change-id>`. Re-check `jj log` after each rewrite because descendant IDs change.

6. **Resolve the tip last** — after all ancestors are clean, edit the newest conflicted revision.

7. **Leave the branch clean** — `jj new` to create an empty working-copy change. End state: `jj status` shows no changes, no `(conflict)` in `jj log`.

## Decision Rules

- **Same file conflicts across multiple revisions**: Use the final resolved version as reference; for each ancestor, remove changes belonging only to later commits.
- **Conflict mixes behavior and presentation**: Preserve destination-branch behavioral additions first, then layer this revision's presentation changes on top.
- **Ancestor resolution re-conflicts the tip**: Expected — do not undo the ancestor fix. Re-edit the descendant against the newly rewritten parent.

## Guardrails

- Do not abandon or squash revisions to hide conflicts unless the user explicitly wants history rewritten.
- Do not force later-revision changes into earlier revisions unless required for correctness.
- Do not leave conflict markers in files even if `jj` no longer reports the active revision as conflicted.

## Tool Sequence

`jj status` → `jj log` → `jj show <change>` → `jj edit <change>` → edit file → `jj status` → `jj log` → repeat → `jj new`
