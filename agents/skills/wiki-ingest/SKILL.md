---
name: wiki-ingest
description: Ingest a source document into the LLM Wiki. Process a file from raw/, a daily journal entry, or a URL into wiki pages with summaries, entity/concept updates, and cross-references.
argument-hint: "[source-path or URL]"
allowed-tools: Read Glob Grep Write Edit Bash(mv *) Bash(cp *) Bash(ls *) Bash(mkdir *) WebFetch
---

# Wiki Ingest

You are maintaining an LLM Wiki in this Obsidian vault. Read `AGENTS.md` at the vault root for the full schema and conventions.

## Your task

Ingest the source specified by `$ARGUMENTS` into the wiki.

## Workflow

1. **Locate the source.** If `$ARGUMENTS` is:
   - A file path: read it directly
   - A URL: fetch the content with WebFetch, then save as a markdown file in `raw/` (use kebab-case filename)
   - Empty: ask the user what to ingest

2. **Ensure the source is in `raw/`.** If the file isn't already in `raw/`, move or save it there. Never modify files already in `raw/`.

3. **Read the source thoroughly.** Understand the key information, entities, concepts, and claims.

4. **Discuss with the user.** Briefly share 3-5 key takeaways and ask if there's anything specific to emphasize or de-emphasize before writing wiki pages.

5. **Create a source-summary page** in `wiki/` named `src-<descriptive-name>.md` with frontmatter:
   ```yaml
   ---
   title: "Source: <Title>"
   type: source-summary
   tags: [relevant, tags]
   sources: [filename-in-raw.md]
   created: YYYY-MM-DD
   updated: YYYY-MM-DD
   ---
   ```

6. **Create or update entity pages** for people, organizations, products, or places mentioned. If a page exists, update it with new information and note the new source. If new information contradicts existing content, flag the contradiction explicitly.

7. **Create or update concept pages** for ideas, frameworks, patterns, or techniques. Same update-or-create logic as entities.

8. **Update cross-references** on any existing wiki pages that now relate to the new source. Add `[[wikilinks]]` where relevant.

9. **Ensure every new or updated page has a `description:` frontmatter property, then regenerate the index.** Run:
   ```
   python3 scripts/wiki-index-generator.py
   ```
   This parses `wiki/index.base`, scans all wiki pages, and regenerates `wiki/index.md` from frontmatter. The index drives human discovery in Obsidian.

10. **Append to `wiki/log.md`** with format:
    ```
    ## [YYYY-MM-DD] ingest | <Source Title>

    <Brief description of what was created/updated. List pages touched.>
    ```

## Guidelines

- Read `wiki/index.md` first to understand what pages already exist
- Prefer updating existing pages over creating new ones when topics overlap
- Use `[[wikilinks]]` liberally for cross-references
- Use kebab-case filenames
- A single source may touch 10-15 wiki pages — that's expected
- Keep summaries concise but thorough

