---
name: code-review
description: "Review code changes and provide actionable feedback on bugs, structure, and behavior. Accepts uncommitted changes, a commit hash, branch name, or PR URL/number."
---

Input: $ARGUMENTS

## Determining What to Review

1. **No arguments**: Review all uncommitted changes — run `git diff`, `git diff --cached`, `git status --short`
2. **Commit hash**: Run `git show $ARGUMENTS`
3. **Branch name**: Run `git diff $ARGUMENTS...HEAD`
4. **PR URL or number**: Run `gh pr view $ARGUMENTS` then `gh pr diff $ARGUMENTS`

## Gathering Context

Diffs alone are not enough. Read the full file(s) being modified to understand context.

- Use the diff to identify which files changed
- Read the full file to understand existing patterns, control flow, and error handling
- Check for conventions files (CONVENTIONS.md, AGENTS.md, CLAUDE.md, .editorconfig)

## What to Look For

**Bugs** — primary focus:
- Logic errors, off-by-one mistakes, incorrect conditionals
- Missing guards, unreachable code paths, race conditions
- Security issues: injection, auth bypass, data exposure
- Error handling that swallows failures or throws unexpectedly

**Structure** — does the code fit the codebase?
- Follows existing patterns and established abstractions?
- Excessive nesting that could be flattened with early returns?

**Performance** — only if obviously problematic:
- O(n²) on unbounded data, N+1 queries, blocking I/O on hot paths

**Behavior Changes** — raise if introduced, especially if possibly unintentional.

## Before Flagging

- Only review the changes — not pre-existing unmodified code
- Don't flag something as a bug if you're unsure — investigate first
- Don't invent hypothetical problems — explain the realistic scenario where it breaks
- Don't flag style preferences unless they clearly violate established conventions

## Output

1. Be direct and clear about why something is a bug
2. Don't overstate severity
3. Explicitly state the scenario/input required for the issue to arise
4. Matter-of-fact tone — not accusatory or overly positive
5. Avoid flattery — no "Great job", "Thanks for"
