---
name: radar-navigation
description: Orient in a repository by jumping to an exact file#symbol anchor instead of grepping or listing the tree. Use when you need to find where code lives ("where is X", "how does Y work", "where is Z handled") in an unfamiliar or large repo. Requires the `radar` CLI; fall back to a targeted grep or the explore subagent if it is unavailable or the repo's language is unsupported.
license: MIT
compatibility: Requires the `radar` CLI (crate `rdar`). Works in Claude Code and OpenCode.
metadata:
  category: navigation
  requires: radar
---

## What I do

Use `radar` — a local, model-free code index (Tree-sitter + reference graph + PageRank + term-rarity ranking) — to turn a natural-language intent into an exact `file#symbol` anchor, so you read the right place instead of exploring the tree. It runs entirely locally: no network, no model, no vector DB. (radar is MIT-licensed.)

## When to use me

- Orienting in an unfamiliar or large repository.
- Any "where is X / how does Y work / where is Z handled" question beyond a trivial exact-symbol lookup.
- Before delegating implementation to another agent — resolve the anchor first and pass it down so nothing re-explores.

## Language coverage (check before trusting the anchor)

radar v0.3.0 has full symbol/graph support only for these grammars:
**rust, python, javascript, typescript/tsx, go, java, c, c++, c#, php, ruby, bash.**

Other languages — including **Apex (.cls/.trigger), KCL, Lua, HTML, YAML** — are **not** parsed; radar degrades to lexical/rare-term ranking there, so its anchors are weaker. In an unsupported-language repo, prefer a targeted exact-symbol grep or the language server, and treat radar output as a hint, not ground truth.

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

- `radar refresh` — update changed areas after edits (`--since HEAD~1` for a commit range, `--deep` for a full re-index).
- `radar status` — report index freshness.
- `radar check` — validate committed maps.

Staleness is tracked via content hashes + git tree identity. The `.radar/` fast-path files are disposable and rebuild automatically; they are gitignored globally by the dotfiles. Config lives in `radar.toml` at the repo root.

## Setup (one-time, human)

radar is alpha, MIT-licensed, and lives in a private repo (`github.com/Sanix-Darker/radar`; crate `rdar`, binary `radar`). Install one of:

- From a clone (canonical): `cargo install --locked --path ~/Projects/radar`
- From a release archive: extract, then `install -m 0755 <bundle>/radar ~/.local/bin/radar`
- Possibly `cargo install rdar`, if it is published to crates.io.

Then, per repo: `radar map`, then `radar init`. Committing `MAP.md` gives a durable router across clones/context resets (optional).
