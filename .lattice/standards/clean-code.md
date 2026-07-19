---
mode: overlay
---

> This document overlays project-specific customizations on top of the clean-code atom's embedded defaults. Only sections included here differ from the defaults -- all other sections remain as-is.
>
> Sections below replace matching sections in the defaults (matched by heading). New sections are appended after defaults.

**Table of contents (included sections only):**

8. [Error Handling](#8-error-handling)
9. [Test-Friendly Code](#9-test-friendly-code)
11. [Scope: What Clean-Code Governs](#11-scope-what-clean-code-governs)
12. [Language Idioms (Imperative Layer)](#12-language-idioms-imperative-layer)
13. [Secrets Handling](#13-secrets-handling)

---

## 8. Error Handling

This repo's imperative layer is a **batch build/deploy tool**, not a long-running service. There is no request middleware to catch and translate errors, and no state to recover — a bad config must never be silently deployed. The rule is **fail-fast at the process boundary**, not exception-based recovery.

### Core Principles

| Principle | Rationale |
|-----------|-----------|
| **Fail fast, fail loud** | The moment a build or validation step detects a problem, abort the whole pipeline with a non-zero exit. A partially-generated or unvalidated config must never reach deploy. |
| **Exit, don't recover** | Python fatal errors call `sys.exit(1)`; shell steps run under `set -eu` and `exit 1`. There is no "handle at a higher level" — the top level *is* the shell exiting non-zero. |
| **Diagnostics to stderr** | Every failure prints an actionable message to stderr (Python: direct to `sys.stderr`; shell: `_ERR`/`_WARN` from `lib.sh`) before exiting. stdout is reserved for real output. |
| **`raise` for internal contract violations** | Use `raise TypeError`/`ValueError` for "this should never happen" internal bugs (e.g. a non-dict passed to the TOML writer). Reserve `sys.exit(1)` for expected operational failures (missing input file, missing dependency). |
| **Never swallow** | A validator that finds a problem must exit non-zero. An empty `except:` or a `_WARN` where a hard failure is warranted lets a broken config deploy — the worst outcome. |
| **Warn vs fail deliberately** | `_WARN` (continue) is only for genuinely non-fatal conditions (an optional tool absent, an advisory check). If the artifact would be wrong, it is `_ERR` + `exit 1`, not a warning. |

### Patterns

**Fatal operational error — exit with an actionable diagnostic:**

```
# Python (build layer)
if not config_path.exists():
    print(f"error: {config_path} not found; run `kcl run` first to generate it", file=sys.stderr)
    sys.exit(1)
```

```
# Shell (deploy layer) — set -eu is already active
if ! command -v dotter >/dev/null 2>&1; then
    _ERR "dotter not found on PATH; install it (see README) before deploying"
    exit 1
fi
```

**Internal contract violation — raise, don't exit:**

```
# A caller passed the wrong type — this is a bug in our code, not user error
if not isinstance(data, dict):
    raise TypeError(f"_write_toml expects a dict, got {type(data).__name__}")
```

**Actionable messages — say what failed and what to do:**

```
# POOR
_ERR "validation failed"
print("bad config", file=sys.stderr)

# GOOD
_ERR "taplo lint failed for out/starship.toml; fix the TOML in src/starship.k and re-run ./deploy.sh"
print(f"missing dependency 'tomli_w'; run: pip install -r requirements.txt", file=sys.stderr)
```

**Never swallow a validation result:**

```
# POOR — a failed check that only warns lets a broken config deploy
if not toml_is_valid(path):
    _WARN "toml looks off"        # then continues to deploy anyway

# GOOD — a failed invariant aborts the pipeline
if not toml_is_valid(path):
    _ERR "generated TOML at $path is invalid; aborting before deploy"
    exit 1
```

---

## 9. Test-Friendly Code

This is a config repository — there is **no unit-test framework** (no pytest, no assertion library). "Testable" here means **verifiable by the validation pipeline** and **runnable in isolation**, not "mockable in a unit test." Do not add DI seams, mock objects, or unit-test scaffolding for the build/deploy scripts; verify them the way the repo already does.

**Every new generated artifact needs a validator.** If you add output to the KCL→TOML pipeline, add or extend the matching check so a bad artifact fails the build:
- Existence + parse + structural checks → `scripts/dotter/validate_generated.py` / `validate_toml.py` / `validate_jsonc*.py`
- Syntax / schema / deployed-config checks → `scripts/dotter/validate_schema.sh` (`--pre-deploy` / `--post-deploy`)
- End-to-end pipeline in a temp dir → `scripts/dotter-ci/` (wired by `.gitea/workflows/validate-dotter.yml`)

**Scripts must run in isolation — no dependency on the developer's real `~/`.** CI deploys the whole pipeline into a throwaway temp dir. A script that only works against your actual home directory, or that mutates real state to do its job, is not verifiable. Resolve paths through `lib.sh` helpers (`resolve_repo_root`, `ensure_dotter_dir`) rather than hardcoding `$HOME`.

**Determinism.** The same KCL source + `local.toml` must always produce the same generated output. No timestamps, machine names, or environment-dependent values baked into committed/generated artifacts (those are per-machine `local.k` or runtime secret-injection concerns). Deterministic output is what makes the validators meaningful.

**Separate pure transform from I/O — but for the same reason the defaults give.** `generate_from_kcl.py` already splits parsing/resolution (pure) from `file.write()` (I/O). Keep that shape: a value-transforming helper should compute and return; writing to disk happens in a distinct, thin step. This keeps the transform logic inspectable without running the whole pipeline.

**What still applies from the defaults:** pure functions for value transformation, no hidden mutable global state, side effects (file writes, `security`/`pass-cli` calls) pushed to the edges. What does **not** apply: injecting dependencies for the sake of mockability, and writing unit tests — the validator pipeline is the test suite.

---

## 11. Scope: What Clean-Code Governs

Clean-code craft rules (function size, complexity, parameter design, extraction) apply to the **imperative layer only**. Applying them to declarative config is a category error.

**Governed by clean-code:**
- Python build/validation scripts — `scripts/**/*.py`
- Shell build/deploy scripts — `scripts/**/*.sh` (including `pre_deploy.sh`, `post_deploy.sh`, `scripts/secrets/*.sh`)
- Lua validators / helpers that are real logic — e.g. `scripts/dotter/validate_lsp.lua`

**NOT governed by clean-code:**
- **KCL source** (`src/*.k`, `src/_shared/`) — declarative config data. Its craft rules live in `language-idioms.md` (schema design, naming, `_shared` composition) and `architecture.md` (layer/dependency rules). Do **not** flag a KCL schema for "too many fields," a `main.k` composition for "function too long," or a config binding for "cyclomatic complexity." Depth and length in declarative config are inherent, not a smell.
- **Static config trees** (`src/nvim/` Lua, `src/ghostty/` shaders, `src/opencode/` prompts, tmux/starship config, …) — end-user tool configuration deployed directly by dotter. These follow each tool's own conventions, not this repo's code-craft rules. A long Neovim plugin setup or a dense shader is not a clean-code violation.

When reviewing a change, first decide which layer the file is in. If it is declarative config or a static tree, defer to `language-idioms.md` / `architecture.md` / the tool's own norms — not the function-size and complexity thresholds in the defaults above.

---

## 12. Language Idioms (Imperative Layer)

The imperative layer is small (single-purpose scripts, no framework). These are the concrete idioms to match.

### Python (`scripts/**/*.py`)

- **Linter is the baseline.** Ruff config lives at `scripts/dotter/.ruff.toml`: `select = [E, F, I, N, W, UP, B, C4, SIM]`, google-style docstrings, double quotes, space indent, LF. Write code that passes it without waivers; `E501` (line length) is the only ignored rule (formatter owns wrapping).
- **Target `py39` for portability.** `.ruff.toml` sets `target-version = "py39"` because scripts must run on whatever system Python a fresh machine has. Avoid 3.10+-only syntax (structural `match`, PEP 604 `X | Y` in runtime-evaluated positions) even though the dev runtime is newer.
- **Module-private helpers get a leading underscore** (`_load_json`, `_write_toml`, `_resolve_template_value`). The public surface of a script is `main()`; everything else is `_`-prefixed.
- **Keyword-only flags via `*`** for optional/boolean parameters (`def _write_toml(data, out_path, *, header=None, template=False)`) so call sites read self-documenting — this is the repo's answer to the boolean-parameter smell in §5.
- **Minimal dependencies.** The only third-party deps are `tomli` / `tomli_w` (see `requirements.txt`). Prefer the standard library; a missing optional dependency is a `sys.exit(1)` with an install hint, not a silent fallback.
- **Snake_case** everywhere (enforced by `N`); TOML/JSON output keys preserve the *target tool's* native casing (e.g. `"default-command"`), which is data, not identifier naming.

### Shell (`scripts/**/*.sh`)

- **`set -eu` at the top** of every executable script — fail on error, fail on unset variable. (Sourced-only libraries like `lib.sh` may omit it, but callers run under it.)
- **Source `scripts/dotter/lib.sh`** for shared behavior instead of re-implementing it: `resolve_repo_root`, `resolve_python`, `ensure_dotter_dir`, `regenerate_from_kcl`, `run_with_timeout`, `begin_wait`, and the `_ERR` / `_WARN` logging helpers. This is the repo's dependency-injection seam for shell.
- **Diagnostics through `_ERR` / `_WARN`**, not bare `echo` — consistent formatting to stderr, and the fail-vs-warn distinction from §8 stays explicit.
- **Guard optional tools** with `command -v <tool> >/dev/null 2>&1` (or `(( ${+commands[...]} ))` in zsh-only contexts) before invoking them — the same pattern used for `zoxide`/`atuin`/`starship` init in the shell configs.
- **POSIX-safe where it will be sourced non-interactively** (the `zshenv` boundary): scripts or fragments loaded by non-interactive shells / MCP servers must not rely on zsh-only syntax. Interactive-only scripts may use zsh features.

---

## 13. Secrets Handling

Secrets are a first-class, enforceable concern in this repo. The governing principle — stated verbatim in both secret backends — is:

> **Secrets are injected into specific config files only (during `dotter deploy`) and never exported as shell environment variables.**

### Rules

| Rule | Detail |
|------|--------|
| **Never commit a secret** | Secrets live in **macOS Keychain** (`security` CLI) or **Proton Pass** (`pass-cli`) — never in `src/*.k`, committed files, `out/`, or `.dotter/global.toml`. |
| **Never export to the shell env** | Retrieval writes to a gitignored cache (`~/.cache/{macos-keychain,proton-pass}-secrets.env`, 1-hour max age) and is injected into target config files at deploy time. Do not add `export TOKEN=$(security find-…)` to any rc file. |
| **Two interchangeable backends, one CLI** | `scripts/secrets/macos-keychain-env.sh` and `scripts/secrets/proton-pass-env.sh` expose the same interface: `--build`, `--get KEY`, `--keys`, `--status`, `--clear`. A new backend matches this interface — no bespoke API. |
| **Key name == output key name** | The store's service/key name matches the emitted key exactly (Keychain `-s HA_TOKEN` → key `HA_TOKEN`). Keep names identical across backends so they stay swappable. |
| **Injection point is `post_deploy.sh`** | The "injecting secrets" step is the single place secrets enter deployed files. Wire new secrets there, using `run_with_timeout` for headless safety and the existing keychain-lock handling (`_keychain_is_unlocked` / `_try_unlock_keychain`). |
| **Profile-scoped retrieval** | Shared secrets (e.g. GitHub PAT) are always fetched; personal-only / work-only secrets are fetched only under the matching active dotter profile (auto-detected from `.dotter/local.toml` `packages`, overridable via `OPENCODE_PROFILE_*`). Declare a new secret's scope; don't fetch work secrets on a personal machine. |
| **Placeholders in tracked templates, not values** | Config templates carry `{{ placeholder }}` (Handlebars) or JSONC placeholder tokens; the real value is substituted at deploy (`patch_opencode_secrets.py`, template rendering). Never bake a resolved secret into a tracked file. |
| **Never blank a live-injected secret** | Runtime-rewritten apps render to `~/.cache/dotfiles/*.rendered.*` and are merged into the live file via `merge_json_config.py`. Injected secrets live only in keys *absent* from the rendered template — that is what makes `--replace` safe. Preserve this: a deploy without secret access (locked keychain) must leave existing tokens intact, never overwrite them with empty values. |
| **Gitignore new secret surfaces** | `local.k`, `.dotter/local.toml`, `.env_meta.json`, and everything under `~/.cache` stay out of the repo. Any new secret-bearing surface is gitignored before its first deploy. |
| **Fail without leaking** | If a secret is missing or the keychain is locked, `_WARN` / skip and leave config intact. Never print a secret value in a diagnostic, and never fall back to a hardcoded default credential. |

### Anti-patterns to flag

- [ ] **Committed / hardcoded secret**: a token, password, or key literal in `src/*.k` or any tracked file → move it to Keychain / Proton Pass and inject via `post_deploy.sh`.
- [ ] **Secret exported to shell env**: `export FOO=<secret>` or an rc-file lookup that puts a secret in the environment → write it to the target config file at deploy time instead.
- [ ] **Resolved value in a template**: a real credential where a `{{ placeholder }}` belongs → replace with the placeholder and inject on deploy.
- [ ] **Destructive merge**: a rendered template that overwrites a live-injected secret key (blanks it when secret access is unavailable) → keep injected keys out of the rendered template so the merge preserves them.
- [ ] **Secret in a diagnostic / log**: an `_ERR`/`print` that echoes the secret value → log the key name and remediation, never the value.

---

## 14. Neovim / Lua Addendum

The Neovim config (`src/nvim/`) is a **static tree deployed as a dotter template** — its Lua content is not transformed by the KCL→TOML pipeline, but the files *are* rendered by dotter (e.g. `init.lua` carries the `{{vim_set_num_relnum}}` marker). Follow Neovim/Lua idioms here, not the imperative-layer thresholds from §2/§3 (per §11, this tree defers to the tool's own norms — the norms below).

### Structure conventions

- **Per-profile layout**: `src/nvim/{default,work,personal}/`. `default/` is the base; `work/` and `personal/` extend or override it by mirroring the same layout. Add profile-specific files rather than forking the whole config.
- **Entry flow**: `init.lua` sets `vim.g.mapleader`, then `require("config.<module>")` for each core module, then plugin/LSP wiring. Keep `init.lua` thin — orchestration only.
- **Core modules** live in `lua/config/` (`formatting.lua`, `keymaps.lua`, `lsp.lua`, `pack.lua`, `neovide.lua`, …), one concern per file, loaded by name via `require("config.<name>")`.
- **Plugins** live in `lua/plugins/`, **one file per plugin**. Adding a plugin = a new file, not an edit to a monolithic list.
- **LSP servers** live in `lsp/<server>.lua` (native Neovim 0.11+ `vim.lsp.config` / `vim.lsp.enable` convention — e.g. `basedpyright.lua`, `gopls.lua`, `kcl_lsp.lua`, `lua_ls.lua`). Add a server = a new file here, matching the existing ones.

### Plugin manager

- **Use the built-in `vim.pack`** (Neovim 0.12) — **not** lazy.nvim, packer, or vim-plug. A plugin spec is `vim.pack.add({ { src = "https://github.com/owner/repo" } })` followed by `require("<module>").setup({ … })`.
- `config/pack.lua` patches `vim.pack.add` so specs in `lua/plugins/*.lua` need not pass `opts`, and registers core dependencies (that must load during init) *before* other `add` calls. Respect that ordering — plugins depending on a core dep are added after it in `pack.lua`.

### Lua style

- Match Neovim Lua idioms: `vim.opt` for options, `vim.keymap.set` for maps, `vim.api.nvim_create_autocmd` **with an augroup** (`vim.api.nvim_create_augroup(name, { clear = true })`) so reloads don't stack duplicate autocmds.
- 2-space indentation; `local`-scope modules and helpers; return a table from a module when it exposes an API. There is no in-repo `stylua`/`luacheck` config — match the surrounding file's style rather than importing external rules.
- Guard optional integrations (a plugin that may be absent, an external binary) before calling into them, mirroring the shell `command -v` guard discipline.

### Templating & verification

- These files pass through dotter templating: keep Handlebars `{{ … }}` markers **balanced** and reference only placeholders defined for the profile (the generated-config validators check `{{#if}}/{{/if}}` balance and cross-reference placeholders against `local.toml`). Don't hardcode a value that should be a per-profile template variable, and don't leave an unknown/unbalanced placeholder.
- Every change must survive the CI gate: `nvim --headless +"qa!"` startup with **zero load-time errors**, plus the LSP health check — both run against a throwaway temp deploy dir (`scripts/dotter-ci/test-nvim-startup.sh`). A config that errors or prints at load time fails CI. Do not rely on the developer's real `~/.config`.

---

*Generated for the dotfiles repository on 2026-07-19. Mode: overlay.*
*Produced by the clean-code-refiner skill.*
