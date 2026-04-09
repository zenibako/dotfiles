---
description: Run CodeRabbit AI code review on current changes using structured agent output. Complements OpenCode's native /review command with CodeRabbit's specialized review.
---

# CodeRabbit Review

Run CodeRabbit AI code review on the current working directory changes. Uses structured `--agent` output format optimized for AI consumption.

## Usage

Run CodeRabbit review on current changes:

```bash
coderabbit review --agent
```

Review only uncommitted changes:

```bash
coderabbit review --agent --type uncommitted
```

Review changes against a specific base branch:

```bash
coderabbit review --agent --base main
```

## Recommended Command

For comprehensive review of all changes:

```bash
coderabbit review --agent --type all
```

## Options

- `--agent` - Output structured agent-friendly findings (recommended for AI)
- `--type <type>` - Review type: `all`, `committed`, `uncommitted` (default: "all")
- `--base <branch>` - Base branch for comparison
- `--config <files...>` - Additional instructions (e.g., claude.md, coderabbit.yaml)

## Agent Output Format

The `--agent` flag provides structured JSON-like output that includes:
- File-level findings with severity
- Line-specific suggestions
- Actionable recommendations
- Category tags (security, performance, style, etc.)

## Comparison to Native /review

| Feature | OpenCode /review | /coderabbit-review |
|---------|------------------|--------------------|
| **Provider** | OpenCode's AI | CodeRabbit CLI |
| **Output format** | Human-readable | Machine-readable (JSON) |
| **Best for** | Human consumption | Programmatic processing |

## Examples

### Review current working directory

```bash
coderabbit review --agent
```

### Review committed changes against main

```bash
coderabbit review --agent --base main --type committed
```

### Review with custom configuration

```bash
coderabbit review --agent --config .coderabbit.yaml
```

## Prerequisites

- CodeRabbit CLI installed (`brew install coderabbit`)
- Authenticated (`coderabbit auth login`)
