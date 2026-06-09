---
name: kcl
description: >
  KCL (K Configuration Language) fundamentals for any project. Covers schema design,
  module organization, import patterns, string interpolation gotchas, and KCL/Python
  hybrid pipelines. Use when writing, refactoring, or debugging KCL configuration code.
compatibility: Requires KCL CLI v0.12.3+.
metadata:
  author: chanderson
  version: "1.0"
---

# KCL (K Configuration Language)

## When to use

- When writing or modifying KCL schemas and configuration
- When debugging KCL compilation errors
- When organizing KCL code into modules
- When KCL string interpolation behaves unexpectedly
- When designing a KCL → target format pipeline (JSON, TOML, YAML, text)

## Language Basics

### Schemas

Schemas define typed structures with optional fields and defaults:

```kcl
schema Person:
    name: str
    age?: int = 0
    email?: str

p = Person {
    name = "Alice"
    email = "alice@example.com"
}
```

- Required fields: `name: str`
- Optional fields: `age?: int`
- Defaults: `age?: int = 0`
- Mixed types: `files?: {str: FileEntry | str}`

### Imports and Modules

KCL resolves files in the same directory as a single package:

```kcl
# schemas.k — defines types
schema Config:
    value: str

# main.k — imports and uses
import schemas

c = schemas.Config {
    value = "hello"
}
```

**Directory modules:** When a directory and `.k` file share a name, KCL resolves `import foo` to the directory (treating it as a package with its own `main.k` or `__init__.k`):

```
foo/
  main.k     # KCL reads this when you `import foo`
foo.k        # IGNORED — directory takes precedence
```

**Subdirectory imports:** Use `import <dirname>` to import a subdirectory module:

```kcl
import shared

s = shared.SomeSchema {}
```

**No `kcl.mod` needed** for same-directory siblings — KCL auto-discovers them.

### Dictionaries and Lists

```kcl
# Dictionary
settings = {
    editor = "nvim"
    theme = "dark"
}

# Nested dictionary with string keys containing dots
gaps = {
    "inner.horizontal" = 10
    "inner.vertical" = 10
}

# List
workspaces = ["1", "2", "3"]

# List of dictionaries
rules = [
    { app = "Chrome", workspace = 1 }
    { app = "Slack", workspace = 2 }
]
```

### String Types

KCL has three string types. **Critical**: `${...}` is interpolated in **ALL** of them:

```kcl
# Single quotes — interpolated
a = '${HOME}/bin'      # ERROR: KCL tries to resolve ${HOME}

# Double quotes — interpolated
b = "${HOME}/bin"      # ERROR: same

# Triple quotes — ALSO interpolated
c = """${HOME}/bin"""  # ERROR: same

# Workaround: build from literals
_dollar = "$"
_brace_open = "{"
path = _dollar + _brace_open + "HOME" + "}/bin"   # OK: produces "${HOME}/bin"
```

**Rule of thumb:** If you need literal `${` in KCL output, construct it outside schema bodies via string concatenation.

## File Organization Conventions

### Small Projects (single file)

```
project/
└── main.k          # schemas + data + output
```

### Medium Projects (domain modules)

```
project/
├── main.k          # orchestration, imports domains, writes output
├── network.k       # network config
├── compute.k       # compute config
└── storage.k       # storage config
```

### Large Projects (nested packages)

```
project/
├── main.k
├── _shared/
│   └── schemas.k   # all type definitions
├── network/
│   └── main.k      # network config (directory module)
├── compute/
│   └── main.k
└── storage/
    └── main.k
```

**Conventions:**
- `_shared/` or `_lib/` for schemas and utilities (underscore prefix = not a domain)
- Directory modules when the config directory already exists in the project
- Root `.k` files for standalone domains

## KCL → Target Format Pipelines

KCL has no native TOML/YAML/text encoder. Common pattern:

```
KCL ──→ json.encode() ──→ JSON file ──→ Python script ──→ TOML/YAML/text
```

**KCL side:**

```kcl
import json
import file

config = {
    name = "myapp"
    settings = {
        port = 8080
    }
}

file.write("output.json", json.encode(config, indent=2))
```

**Python side:**

```python
import json
import tomli_w

with open("output.json") as f:
    data = json.load(f)

with open("config.toml", "wb") as f:
    tomli_w.dump(data["settings"], f)
```

This is the pattern used by the dotfiles repo's KCL pipeline.

## Critical Gotchas

### 1. `${...}` Interpolation

KCL interpolates `${identifier}` in **all string types**. This breaks:
- Shell variable syntax (`${HOME}`, `${USER}`)
- Starship format strings (`${custom.jj_change}`)
- Any target format that uses `${...}`

**Workaround:**

```kcl
_dollar = "$"
_brace_open = "{"
_brace_close = "}"

# Build the string piece by piece
format = _dollar + "username" + _dollar + _brace_open + "custom.metric" + _brace_close
```

### 2. Directory Shadowing

If `foo.k` and `foo/` both exist, `import foo` resolves to the **directory**, ignoring the `.k` file.

**Solution:** Move the `.k` file into the directory as `foo/main.k`.

### 3. Schema Defaults Don't Flow

Default values in schemas are only applied when the field is omitted. Explicitly setting `field = None` or `field = {}` overrides the default.

### 4. No `append()` or `+=`

KCL has no imperative list/dict mutation. Build complete data structures declaratively:

```kcl
# NOT supported:
# items.append("new")

# Instead:
items = ["old1", "old2", "new"]
```

### 5. Boolean vs String `true`/`false`

KCL uses Python-style `True`/`False`. When targeting TOML, the Python converter must translate these to lowercase `true`/`false`.

### 6. Triple-quoted Strings and YAML Blocks

KCL triple-quoted strings (`"""..."""`) preserve newlines. When these are JSON-encoded and Python-converted to TOML, they become literal multiline strings. Ensure your converter handles multiline TOML values correctly (using `tomli_w` usually does).

## Debugging

```bash
# Compile and see YAML output
kcl run main.k

# Compile only, no output
kcl run main.k --disable_none

# Check for syntax errors
kcl vet main.k

# Format KCL files
kcl fmt main.k
```

## Best Practices

1. **Schemas first** — Define types in `_shared/schemas.k` before writing data
2. **One domain per file** — Keep modules focused (themes.k, profiles.k, etc.)
3. **No logic in schemas** — Schemas are types; computation happens in module bodies
4. **Export via `file.write`** — Use `json.encode()` + `file.write()` for pipeline output
5. **Validate at every step** — KCL compiles → JSON parses → Python converts → target format validates
6. **Document `${...}` workarounds** — Any string building with `$` + `{` needs a comment explaining why

## Resources

- KCL docs: https://kcl-lang.io/docs/
- KCL modules: https://kcl-lang.io/docs/user_docs/guides/modules/
- This repo's `_shared/schemas.k` for real-world schema patterns
