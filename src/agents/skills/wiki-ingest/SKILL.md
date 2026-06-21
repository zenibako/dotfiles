---
name: wiki-ingest
description: Ingest a source document into the LLM Wiki. Process a file from raw/, a daily journal entry, or a URL into wiki pages with summaries, entity/concept updates, and cross-references.
argument-hint: "[source-path or URL]"
allowed-tools: Read Glob Grep Write Edit Bash(mv *) Bash(cp *) Bash(ls *) Bash(mkdir *) WebFetch
---

# Wiki Ingest

You are maintaining an LLM Wiki in this Obsidian vault. Read `AGENTS.md` at the vault root for the full schema and conventions. The wiki follows the **Open Knowledge Format (OKF) v0.1** specification for frontmatter and bundle structure.

## Your task

Ingest the source specified by `$ARGUMENTS` into the wiki.

## Pre-flight: OKF Baseline

Before creating new pages, run `python3 scripts/okf-lint.py` to establish a clean baseline. If there are any structural errors (missing `type` fields, malformed frontmatter, etc.), note them but do not fix them unless they block your current ingest.

## Workflow

1. **Locate the source.** If `$ARGUMENTS` is:
   - A file path: read it directly
   - A URL: fetch the content with WebFetch, then save as a markdown file in `raw/` (use kebab-case filename)
   - Empty: ask the user what to ingest

2. **Ensure the source is in `raw/`.** If the file isn't already in `raw/`, move or save it there. Never modify files already in `raw/`.

3. **Read the source thoroughly.** Understand the key information, entities, concepts, and claims.

4. **Discuss with the user.** Briefly share 3-5 key takeaways and ask if there's anything specific to emphasize or de-emphasize before writing wiki pages.

5. **Create a source-summary page** in `wiki/sources/` named `src-<descriptive-name>.md` with frontmatter. **OKF §4.1 requires `type` as the only mandatory field.** Example:
   ```yaml
   ---
   type: source-summary                          # REQUIRED per OKF §4.1
   title: "Source: <Title>"                   # Recommended per OKF §4.1
   description: One-line summary               # Recommended per OKF §4.1 — drives index generation
   tags: [relevant, tags]                      # Optional per OKF §4.1
   sources: [filename-in-raw.md]               # Custom extension — tracks provenance
   created: YYYY-MM-DD                         # Optional per OKF §4.1
   updated: YYYY-MM-DD                         # Optional per OKF §4.1
   ---
   ```

   Valid `type` values in this wiki:
   - `source-summary` — summaries of individual raw documents
   - `entity` — people, organizations, products, places
   - `concept` — ideas, frameworks, patterns, techniques
   - `synthesis` — higher-order insights combining multiple sources
   - `analysis` — responses to queries worth preserving
   - `skill` — capability/usage docs (this file itself)

6. **Create or update entity pages** for people, organizations, products, or places mentioned. If a page exists, update it with new information and note the new source. If new information contradicts existing content, flag the contradiction explicitly.

7. **Create or update concept pages** for ideas, frameworks, patterns, or techniques. Same update-or-create logic as entities.

8. **Update cross-references** on any existing wiki pages that now relate to the new source. Add `[[wikilinks]]` where relevant. OKF §5.3 says consumers MUST tolerate broken links, but prefer valid targets.

9. **Ensure every new or updated page has a `description:` frontmatter property.** This drives the auto-generated `wiki/index.md` via `wiki/index.base`.

10. **Regenerate the index.** Run:
    ```
    python3 scripts/wiki-index-generator.py
    ```
    This parses `wiki/index.base`, scans all wiki pages, and regenerates `wiki/index.md` from frontmatter. The script also emits `okf_version: '0.1'` in the root index frontmatter per OKF §11.

11. **Run OKF conformance check.** After all pages are written and the index is regenerated:
    ```
    python3 scripts/okf-lint.py
    ```
    Fix any new structural errors before finishing.

12. **Append to `wiki/log.md`** with format (OKF §7 date convention):
    ```
    ## [YYYY-MM-DD] ingest | <Source Title>

    <Brief description of what was created/updated. List pages touched.>
    ```

## Guidelines

- Scan `wiki/` with Glob to discover existing pages, or run `python3 scripts/wiki-index-generator.py` to regenerate `wiki/index.md` from `wiki/index.base`. Read frontmatter (especially `description:`) to understand topics and avoid duplicates. The `wiki/index.base` file is an Obsidian Dataview config — agents should not rely on it for direct discovery.
- Prefer updating existing pages over creating new ones when topics overlap
- Use `[[wikilinks]]` liberally for cross-references
- Use kebab-case filenames
- A single source may touch 10-15 wiki pages — that's expected
- Keep summaries concise but thorough
- Every new page MUST have frontmatter with a non-empty `type` field — this is the only hard requirement per OKF §4.1 and §9.1

## Index Note

`wiki/index.md` is **auto-generated** from the `description:` frontmatter property on each wiki page via the Dataview query in `wiki/index.base`. **Do not edit `wiki/index.md` directly.** Only ensure every new or updated page has a `description:` property.
