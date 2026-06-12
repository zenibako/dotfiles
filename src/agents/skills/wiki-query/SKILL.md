---
name: wiki-query
description: Query the LLM Wiki to answer a question. Searches wiki pages, synthesizes an answer with citations, and optionally files the answer as a new wiki page.
argument-hint: "[your question]"
allowed-tools: Read Glob Grep Write Edit
---

# Wiki Query

You are querying an LLM Wiki in this Obsidian vault. Read `AGENTS.md` at the vault root for the full schema.

## Your task

Answer the question: **$ARGUMENTS**

## Workflow

1. **Scan `wiki/` with Glob and read frontmatter (especially `description:`) to find relevant pages.** The `wiki/index.base` file is an Obsidian Dataview config that generates the human-facing index — agents should not rely on it for discovery.

2. **Read relevant wiki pages.** Follow `[[wikilinks]]` to gather additional context. If the index doesn't seem to cover the topic, search `wiki/` with Grep for keywords.

3. **If wiki pages are insufficient**, check `raw/` source documents for additional detail. The wiki should be the primary source, but raw documents have the full original content.

4. **Synthesize an answer** with `[[wikilink]]` citations to wiki pages. Be thorough but concise.

5. **Offer to file the answer.** If the response is substantial, novel, or worth preserving (a comparison, analysis, synthesis, or connection), ask the user if they'd like it saved as a new wiki page. If yes:
   - Create the page in `wiki/` with appropriate type (`analysis` or `synthesis`)
   - Add proper frontmatter (including a `description:` property)
   - Append to `wiki/log.md`:
     ```
     ## [YYYY-MM-DD] query | <Question Summary>

     Filed answer as [[page-name]]. <Brief description.>
     ```

## Output Format

Present answers in clean markdown with:
- `[[wikilinks]]` to relevant wiki pages inline
- Key facts highlighted
- Sources attributed where possible
- If information gaps exist, note what additional sources could help

