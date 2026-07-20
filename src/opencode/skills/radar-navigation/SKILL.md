---
name: radar-navigation
description: Orient in a repository by jumping to an exact file#symbol anchor instead of grepping or listing the tree. Use when you need to find where code lives ("where is X", "how does Y work", "where is Z handled") in an unfamiliar or large repo. Requires the `radar` CLI; fall back to a targeted grep or the explore subagent if it is unavailable.
license: MIT
compatibility: opencode
metadata:
  category: navigation
  requires: radar
---

## What I do

Use `radar` — a local, model-free code index (Tree-sitter + reference graph + PageRank + term-rarity ranking) — to turn a natural-language intent into an exact `file#symbol` anchor, so you read the right place instead of exploring the tree. It runs entirely locally: no network, no model, no vector DB.

## When to use me

- Orienting in an unfamiliar or large repository.
- Any "where is X / how does Y work / where is Z handled" question beyond a trivial exact-symbol lookup.
- Before delegating implementation to another agent — resolve the anchor first and pass it down so nothing re-explores.

## Precondition (radar is optional)

Check it exists before relying on it:

```sh
command -v radar >/dev/null 2>&1
```

If it is missing — or returns no useful answer — fall back to a single targeted `grep`/`glob` for the exact symbol, or delegate the search to the `explore` subagent. Do not tree-walk.

## Query

```sh
radar query "where is order persistence handled?"
```

- A confident result ends with an anchor line, e.g. `FINAL SOURCE ANCHOR: src/orders/store.rs#save_order`.
- An uncertain result returns at most three bounded candidates.

Open the anchored file/region directly; don't re-scan the tree.

## Keep the index fresh (no daemon)

- `radar refresh` — update changed areas after edits.
- `radar status` — report index freshness.
- `radar check` — validate committed maps.

Staleness is tracked via content hashes + git tree identity. The `.radar/` fast-path files are disposable and rebuild automatically; they are gitignored globally by the dotfiles.

## Setup (one-time, human — requires access to the private repo)

radar is **alpha** and access-gated at `github.com/Sanix-Darker/radar`. Once you have access:

1. Install the binary — download the v0.3.0 macOS release archive (clear quarantine with `xattr -d com.apple.quarantine <bin>`), **or** build from a clone:
   ```sh
   gh repo clone Sanix-Darker/radar && cd radar && cargo install --locked --path .
   ```
2. Per repo: `radar map` then `radar init`.
3. `.radar/` is already gitignored globally by the dotfiles. Committing `MAP.md` gives a durable router across clones/context-resets, but is optional.
