---
language: kcl
version: "0.12.x"
---

# Language Idioms: KCL

## Error Handling

KCL has no runtime error handling — it is a declarative config language evaluated at build time. Errors are compile-time validation failures: schema type mismatches, missing required fields, unresolved imports, or `assert` failures. The `kcl run` command either succeeds or fails with a diagnostic; there is no try/catch or Result type. Error prevention is via schema definitions with required vs optional (`?`) fields and type annotations.

The Python build layer (`generate_from_kcl.py`) uses `sys.exit(1)` with diagnostics to stderr on fatal errors (missing `out/config.json`, missing `tomli_w` dependency), and `raise TypeError` for internal contract violations (e.g., non-dict passed to TOML writer). The deploy scripts (`pre_deploy.sh`, `post_deploy.sh`) use `set -eu` and `_ERR`/`_WARN` helpers from `lib.sh` with `exit 1` on failures — fail fast, no silent continuation.

## Type System & Object Model

KCL uses **schemas** as the primary type construct (`schema Name:` with typed fields). Schemas support optional fields (`?`), default values (`= expr`), union types (`"a" | "b"`), and `any` for untyped dicts. No classes, inheritance, or methods — schemas are pure data shapes with validation. Composition is via schema fields referencing other schemas (e.g., `DotterConfig` has `default?: Profile`). `file.write()` and `json.encode()` are built-in functions. Optional fields (`?`) default to absent; there is no `null` literal — unset optionals are omitted from JSON output.

**Schema sourcing idiom**: When a tool has a published JSON schema or config docs, backfill the KCL schema with typed fields rather than using `{str: any}`. Reference table:

| Tool | KCL schema status | JSON schema | Config docs |
|------|------------------|-------------|-------------|
| starship | typed `StarshipConfig` | `https://starship.rs/config-schema.json` | `https://starship.rs/config/` |
| atuin | typed `AtuinConfig` | not published | `https://atuin.sh/docs/config` |
| jj | `{str: any}` | `https://jj-vcs.github.io/jj/latest/config-schema.json` | `https://jj-vcs.github.io/jj/latest/config/` |
| opencode | `str` (JSONC) | `https://opencode.ai/config.json` | `https://opencode.ai/docs/config/` |
| codex | `{str: any}` | `https://developers.openai.com/codex/config-schema.json` | `https://developers.openai.com/codex/` |
| aerospace | partial `AerospaceConfig` | not published | `https://nikitabobko.github.io/AeroSpace/guide.html` |
| ghostty | `str` | not published | `https://ghostty.org/docs/config` |
| iamb | `{str: any}` | not published | `https://iamb.github.io/docs/` |
| gitlogue | `{str: any}` | not published | not available |
| tmux | `{str: any}` | not published | `https://github.com/tmux/tmux/wiki` |
| neovim | Lua (not KCL) | not published | `https://neovim.io/doc/user/` |

Tools without a published schema: read the config docs and define the KCL schema from the documented fields.

## Naming Conventions

KCL uses `snake_case` for variables, schema fields, and module-level identifiers (e.g., `enter_accept`, `keymap_mode`, `path_prepend`). Schema names use `PascalCase` (e.g., `Profile`, `DotterConfig`, `EnvSection`). Constants use `snake_case` with leading underscore for module-private (e.g., `_gpg_backend`, `_signing_behavior` in `jj.k`). String map keys preserve the target tool's native format — TOML keys stay as-is (e.g., `"default-command"`, `"config-version"` with hyphens; `"show_cryptographic_signatures"` with snake_case). Module files are `snake_case.k` (e.g., `opencode_config.k`, `claude_code.k`). Import aliases use `as` with short names (e.g., `import _shared.templates as tpl`, `import kiro_config as kiro_mod`).

## Testing Patterns

No unit test framework — this is a config repo, not application code. "Testing" is validation at three stages:
- **Pre-deploy** (`scripts/dotter/validate_generated.py`): Python script checks that all expected `out/` files exist, TOML parses, JSON is valid, and Handlebars `{{#if}}/{{/if}}` blocks are balanced. Runs as part of `pre_deploy.sh`.
- **Pre-deploy schemas** (`scripts/dotter/validate_schema.sh --pre-deploy`): TOML syntax via `taplo lint` (or Python `tomllib` fallback), Handlebars placeholder cross-reference against `local.toml`, YAML syntax via PyYAML, JSONC syntax for OpenCode config.
- **Post-deploy** (`scripts/dotter/validate_schema.sh --post-deploy`): Validates deployed configs in `~/.config/` — taplo schema validation for TOML, `ghostty +validate-config`, `aerospace list-modes`, Claude Desktop/Code JSON validation, OpenCode JSONC + jsonschema, Lua syntax via `luac`, Neovim headless startup test (`nvim --headless +qa!`), LSP health check.
- **CI** (`.gitea/workflows/validate-dotter.yml`): Runs the dotter-ci scripts (`test-nvim-startup.sh`, `test-apex-parser.sh`) against a temp deploy dir.

Python validators use `sys.exit(1)` on failure, shell validators use `set -eu` + `_ERR`/`exit 1`. No pytest, no assertion library — plain `if`/`exit` fail-fast pattern.

## Parameter & Function Design

KCL is declarative — "functions" are `lambda` expressions used sparingly for helper logic (e.g., `tpl.hb = lambda field: str -> {str: str} { {TEMPLATE_MARKER = field} }`). Module-level values are the primary abstraction: each `*.k` file exports a top-level variable (e.g., `atuin = _shared.AtuinConfig { ... }`) consumed by `main.k`. No named/keyword arguments — KCL lambdas use positional params with type annotations. No multiple returns. No method overloading. Config composition uses schema instantiation with field overrides (e.g., `personal = _shared.Profile { depends = ["default"], files = { ... } }`). String formatting uses `.format()` (Python-like, not Rust-like). The Python build layer uses plain function signatures with `**kwargs` not used; options passed as explicit args or config dicts.

## Dependency Management

KCL has no DI containers or runtime wiring — it's a static config language. "Dependencies" are module imports resolved at build time. The pattern is: define schemas in `_shared/schemas.k` (the type library), import them in tool modules (`import _shared`), compose in `main.k`. Cross-module references go through `_shared` (the shared schema library), not direct module-to-module imports. `main.k` is the composition root — it assembles all module outputs into `config = _shared.ConfigMap { ... }` and writes JSON via `file.write()`. The Python build layer (`generate_from_kcl.py`) is a single-file converter with no external dependencies beyond `tomli_w`; it reads `out/config.json` (KCL output) and writes `.dotter/global.toml` + `out/*.toml`. Deploy scripts source `scripts/dotter/lib.sh` for shared helpers (`resolve_repo_root`, `resolve_python`, `ensure_dotter_dir`, `run_with_timeout`) — this is the shell-level "DI" pattern.