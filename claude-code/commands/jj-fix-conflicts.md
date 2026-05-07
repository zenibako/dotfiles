---
description: Resolve Jujutsu conflicts one revision at a time without collapsing the stack or losing per-commit intent
---

Resolve JJ conflicts sequentially across a stacked branch. Preserve each revision's intent instead of only fixing the branch tip.

## Core Rule

Resolve conflicts **in commit order from oldest conflicted revision to newest conflicted revision**.

Do not start from the tip unless it is the only conflicted revision.

## Sequential JJ Workflow

1. **Inspect the stack.**
   - Run `jj status` to see the active working copy and whether the current revision is conflicted.
   - Run `jj log` with enough history to identify all conflicted revisions in order.
   - Note the exact change IDs that are marked `(conflict)`.

2. **Understand the conflict before editing.**
   - Use `jj show <change>` to understand what that revision was trying to do.
   - Compare the conflicted file from the current conflicted revision, the already-resolved descendant or tip if one exists, and the destination/base revision if needed.
   - Distinguish between destination behavior that must survive, the current revision's own delta, and changes that belong only to later revisions.

3. **Edit the oldest conflicted revision.**
   - Run `jj edit <change-id>` for the oldest conflicted revision.
   - If a later resolved revision already contains the right merged shape, restore the conflicted file from that revision into `@`, then back out any changes that belong to later commits.
   - Otherwise, manually merge the file so this revision contains only the destination branch behavior that must be kept, and this revision's intended change.

4. **Verify immediately after each revision.**
   - Confirm no conflict markers remain in touched files.
   - Run `jj status` to confirm the current edited revision is no longer shown as conflicted.

5. **Move to the next conflicted revision.**
   - Repeat `jj edit <next-change-id>`.
   - Re-check `jj log` after each rewrite because descendant commit IDs will change.

6. **Resolve the tip last.**
   - After ancestor revisions are clean, edit the newest conflicted revision.

7. **Leave the branch clean.**
   - After the top revision is resolved, create a new empty working-copy change with `jj new`.
   - End state: `jj status` shows no changes, no revision in `jj log` is marked `(conflict)`.

## Practical Decision Rules

- **Same file conflicts across multiple revisions**: Use the final resolved version as a reference. For each ancestor revision, remove changes that belong only to later commits.
- **Conflict mixes behavior and presentation**: Keep behavioral additions from the destination branch first, then layer the current revision's presentation changes on top.
- **Ancestor resolution makes the tip conflicted again**: This is expected — do not undo the ancestor fix. Re-edit the descendant and reconcile against the newly rewritten parent.

## Guardrails

- Do not resolve only at the tip when multiple conflicted revisions exist.
- Do not abandon or squash revisions just to hide conflicts unless the user explicitly wants history rewritten that way.
- Do not force later-revision changes into earlier revisions unless required for correctness.
- Do not leave conflict markers in files even if `jj` no longer reports the active revision as conflicted.

## Tool Sequence

```
jj status → jj log → jj show <change> → jj edit <change> → edit file → jj status → jj log → repeat → jj new
```
