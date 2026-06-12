---
name: jj-sequential-conflict-resolution
description: Resolve Jujutsu conflicts one revision at a time without collapsing the stack or losing per-commit intent.
license: MIT
compatibility: opencode
metadata:
  vcs: jujutsu
  workflow: conflict-resolution
---

## What I do

- Resolve JJ conflicts sequentially across a stacked branch.
- Preserve each revision's intent instead of only fixing the branch tip.
- Keep destination-branch behavior when conflicts are functional, then reapply only the styling or behavioral delta that belongs to the current revision.
- Leave the working copy clean with an empty child change after the stack is resolved.

## When to use me

Use this when `jj log` or `jj status` shows one or more conflicted revisions in a stack, especially after a rebase.

Use this instead of a single tip-only fix when:

- More than one revision is marked `(conflict)`.
- A later tip resolution keeps reappearing after rewriting ancestor commits.
- The same file conflicts across multiple stacked revisions.

## Core rule

Resolve conflicts **in commit order from oldest conflicted revision to newest conflicted revision**.

Do not start from the tip unless it is the only conflicted revision.

## Sequential JJ workflow

1. Inspect the stack.

- Run `jj status` to see the active working copy and whether the current revision is conflicted.
- Run `jj log` with enough history to identify all conflicted revisions in order.
- Note the exact change IDs that are marked `(conflict)`.

2. Understand the conflict before editing.

- Use `jj show <change>` to understand what that revision was trying to do.
- Compare the conflicted file from:
  - the current conflicted revision,
  - the already-resolved descendant or tip if one exists,
  - and the destination/base revision if needed.
- Distinguish between:
  - destination behavior that must survive,
  - the current revision's own delta,
  - and changes that belong only to later revisions.

3. Edit the oldest conflicted revision.

- Run `jj edit <change-id>` for the oldest conflicted revision.
- If a later resolved revision already contains the right merged shape, restore the conflicted file from that revision into `@`, then back out any changes that belong to later commits.
- Otherwise, manually merge the file so this revision contains only:
  - the destination branch behavior that must be kept, and
  - this revision's intended change.

4. Verify immediately after each revision.

- Confirm no conflict markers remain in touched files.
- Run `jj status` to confirm the current edited revision is no longer shown as conflicted.
- If needed, inspect `jj diff @- @` or `jj show @` to confirm the rewritten revision still matches its original purpose.

5. Move to the next conflicted revision.

- Repeat `jj edit <next-change-id>`.
- Expect descendant revisions to be rewritten after ancestor resolution.
- Re-check `jj log` after each rewrite because descendant commit IDs will change.

6. Resolve the tip last.

- After ancestor revisions are clean, edit the newest conflicted revision.
- Reapply the final merged content if the ancestor rewrites invalidated the previous tip resolution.

7. Leave the branch clean.

- After the top revision is resolved, create a new empty working-copy change if needed with `jj new`.
- End state should be:
  - `jj status` shows no changes,
  - no revision in `jj log` is marked `(conflict)`,
  - the working copy is an empty child change.

## Practical decision rules

### If the same file conflicts in several revisions

- Prefer using the final resolved version as a reference.
- For each ancestor revision, remove changes that belong only to later commits.
- Think in terms of "what should be true at this exact point in history?"

### If a conflict mixes behavior and presentation

- Keep behavioral additions from the destination branch first.
- Then layer the current revision's presentation changes on top.
- Do not let a style-only revision accidentally absorb later behavior changes unless the conflict makes them necessary to preserve correctness.

### If ancestor resolution makes the tip conflicted again

- This is expected.
- Do not undo the ancestor fix.
- Re-edit the descendant and reconcile against the newly rewritten parent.

## Guardrails

- Do not resolve only at the tip when multiple conflicted revisions exist.
- Do not abandon or squash revisions just to hide conflicts unless the user explicitly wants history rewritten that way.
- Do not force later-revision changes into earlier revisions unless required for correctness.
- Do not leave conflict markers in files even if `jj` no longer reports the active revision as conflicted.

## Suggested tool sequence

- `jj status`
- `jj log`
- `jj show <change>`
- `jj edit <change>`
- inspect or restore file content
- manual merge/edit
- `jj status`
- `jj log`
- repeat for next conflicted revision
- `jj new`

## Done criteria

- All previously conflicted revisions in the stack are clean.
- The working copy has no changes.
- No conflict markers remain in the repo.
- Each revision still reflects its own original purpose when reviewed independently.
