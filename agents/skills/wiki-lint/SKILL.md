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

1. **Scan `wiki/` with Glob and read frontmatter to build a catalog.** Also read `wiki/log.md` to understand recent activity. The `wiki/index.base` file is an Obsidian Dataview config — agents should not rely on it for discovery.

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

5. **Check `wiki/index.base`**
   - Ensure `wiki/index.base` is present and contains the Dataview query that generates `wiki/index.md`.
   - Flag any pages missing the `description:` frontmatter property, as that drives the auto-generated index.

6. **Check `raw/` coverage:**
   - Are there source documents in `raw/` that haven't been ingested (no corresponding `src-*.md` page)?
   - Are there daily journal entries with substantial content that could be ingested?

7. **Present a report** organized as:

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

8. **Ask the user** which issues to fix, then fix them.

9. **Update `description:` on any fixed pages** so the auto-generated index stays current.

10. **Append to `wiki/log.md`**:
    ```
    ## [YYYY-MM-DD] lint | Wiki health check

    <Summary of findings and fixes applied.>
    ```
