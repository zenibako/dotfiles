---
name: wiki-lint
description: Health-check the LLM Wiki. Find contradictions, stale claims, orphan pages, missing cross-references, and content gaps. Run periodically to keep the wiki healthy.
allowed-tools: Read Glob Grep Write Edit
---

# Wiki Lint

You are health-checking an LLM Wiki in this Obsidian vault. Read `AGENTS.md` at the vault root for the full schema.

## Your task

Perform a comprehensive health check of the wiki and report findings.

## Workflow

1. **Read `wiki/index.md`** and **`wiki/log.md`** to understand the current state.

2. **Read every wiki page** in `wiki/`. For each page, note:
   - Outbound `[[wikilinks]]` — do the targets exist?
   - Inbound links — is this page linked from other pages?
   - Frontmatter completeness (title, type, tags, sources, dates)
   - Content freshness — does the `updated` date seem stale relative to source activity?

3. **Build a link graph.** Identify:
   - **Orphan pages** — pages with no inbound links (excluding index.md and log.md)
   - **Broken links** — `[[wikilinks]]` pointing to non-existent pages
   - **Dead ends** — pages with no outbound links to other wiki pages

4. **Check for content issues:**
   - **Contradictions** — claims on one page that conflict with another
   - **Stale claims** — information that newer sources may have superseded
   - **Missing pages** — important concepts or entities mentioned repeatedly but lacking their own page
   - **Thin pages** — pages with very little content that could be expanded
   - **Index gaps** — wiki pages that exist but aren't listed in `wiki/index.md`

5. **Check `raw/` coverage:**
   - Are there source documents in `raw/` that haven't been ingested (no corresponding `src-*.md` page)?
   - Are there daily journal entries with substantial content that could be ingested?

6. **Present a report** organized as:

   ```
   ## Wiki Health Report — YYYY-MM-DD

   ### Stats
   - Total pages: X
   - By type: entities (X), concepts (X), source summaries (X), syntheses (X), analyses (X)
   - Total sources in raw/: X
   - Sources not yet ingested: X

   ### Issues Found
   #### Critical (contradictions, broken links)
   #### Moderate (orphans, missing pages, stale content)
   #### Minor (thin pages, missing cross-references)

   ### Suggestions
   - New pages to create
   - New sources to look for
   - Questions worth investigating
   ```

7. **Ask the user** which issues to fix, then fix them.

8. **Append to `wiki/log.md`**:
   ```
   ## [YYYY-MM-DD] lint | Wiki health check

   <Summary of findings and fixes applied.>
   ```

