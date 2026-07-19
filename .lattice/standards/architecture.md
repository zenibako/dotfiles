---
mode: override
---

> These are the architecture principles for the **dotfiles** repository, following a **custom config-generation pipeline** architecture. This document is the sole reference for the `architecture` atom — there are no embedded defaults.

**Table of contents:**

1. [Layer Definitions](#1-layer-definitions)
2. [Dependency Rules](#2-dependency-rules)
3. [Boundary Rules](#3-boundary-rules)
4. [Per-Layer Rules](#4-per-layer-rules)
5. [Key Flows](#5-key-flows)
6. [Validation Checklist](#6-validation-checklist)
7. [Anti-Patterns](#7-anti-patterns)
8. [Ambiguity Signals](#8-ambiguity-signals)

---

## 1. Layer Definitions

This is a one-way config-generation pipeline: hand-authored source → transformed artifacts → deployed files. Data only ever flows forward. Three pipeline layers, plus a cross-cutting CI harness that exercises the whole pipeline in isolation.

| Layer | Responsibility | Typical Directory |
|-------|---------------|-------------------|
| **1. Source** | The only hand-authored config data — the single source of truth. Two paths: **KCL modules** (`src/*.k`) that get transformed, and **static trees** (`src/<tool>/`) that dotter deploys directly without transformation. | `src/` |
| **2. Build / Transform** | Convert the KCL evaluator's JSON output into deploy-ready TOML, and validate every generated artifact before it is deployed. Pure functions of `out/config.json` — no reach into KCL internals. | `scripts/dotter/` |
| **3. Deploy** | dotter renders templates and symlinks files into `~/`, driven by generated `global.toml` + user `local.toml`. Hooks run the KCL build and inject secrets from Keychain / Proton Pass. | `.dotter/`, `scripts/pre_deploy.sh`, `scripts/post_deploy.sh`, `scripts/secrets/` |
| **CI harness** (cross-cutting) | Exercises Source → Build → Deploy in a throwaway temp dir and asserts the outputs are valid. Never touches the real `~/`. | `scripts/dotter-ci/`, `.gitea/workflows/` |

### Internal structure of the Source layer (KCL modules)

The KCL modules in `src/*.k` have their own strict dependency graph:

| Sub-part | Responsibility | Directory |
|----------|---------------|-----------|
| **Shared library** | Schemas (`Profile`, `DotterConfig`, `ConfigMap`, …), templates, MCP helpers. The type foundation. Depends on nothing. | `src/_shared/` |
| **Tool modules** | One file per tool; exports a single top-level binding (e.g. `atuin = _shared.AtuinConfig { … }`). Import only `_shared`, never each other. | `src/atuin.k`, `src/jj.k`, `src/starship.k`, … |
| **Composition root** | Imports every tool module + `_shared`, assembles `config = _shared.ConfigMap { … }`, and writes `out/config.json` via `file.write()`. The only place modules are wired together. | `src/main.k` |

### Directory Mapping

```
src/                    # Layer 1: Source (source of truth)
├── _shared/            #   shared library — schemas.k, templates.k, mcp.k (depends on nothing)
├── main.k              #   composition root — imports all modules, writes out/config.json
├── profiles.k          #   tool/config modules — import only _shared
├── themes.k
├── *.k                 #   atuin.k, jj.k, tmux.k, ghostty.k, starship.k, env.k, ...
├── nvim/ ghostty/ ...  #   static trees — deployed directly by dotter (NO transform)
└── local.k.example     #   template for gitignored local.k (per-machine + secrets)

scripts/                # Layers 2 & 3
├── dotter/             #   Layer 2: Build/Transform — generate_from_kcl.py, validate_*.py, lib.sh
├── secrets/            #   Layer 3: secret sources (macos-keychain-env.sh, proton-pass-env.sh)
├── pre_deploy.sh       #   Layer 3: KCL build + validate hook
├── post_deploy.sh      #   Layer 3: secret injection + post-deploy validation hook
└── dotter-ci/          #   CI harness — runs the pipeline against a temp dir

out/                    # Generated (gitignored): config.json (KCL output) + *.toml (build output)
.dotter/                # Deploy config (gitignored): generated global.toml + user local.toml
```

---

## 2. Dependency Rules

Two distinct dependency axes govern this repo. Both are strictly one-directional.

### Axis A — Pipeline data flow (never flows backward)

```
  ┌──────────┐   file.write()   ┌───────────────┐   reads config.json   ┌──────────┐
  │  Source  │ ───────────────► │ Build/Transform│ ────────────────────► │  Deploy  │
  │  (src/)  │  out/config.json  │  (scripts/     │   global.toml +       │ (dotter  │
  │          │                   │   dotter/)     │   out/*.toml          │  + hooks)│
  └──────────┘                   └───────────────┘                       └────┬─────┘
       │                                                                      │
       │ static trees (src/nvim, src/ghostty, ...) referenced by             │ deploys to
       └──────────────────── file mappings, deployed as-is ──────────────────► ~/.config, ~/.zshrc, ...
```

- **Source** never imports from Build or Deploy. It emits `out/config.json` and owns static trees; it knows nothing about TOML, dotter, or `~/`.
- **Build/Transform** depends only on `out/config.json`. It must not read `src/*.k`, embed tool-specific config values, or know anything about deploy targets or the user's home dir.
- **Deploy** depends only on the generated `global.toml` + user `local.toml` (plus static trees by reference). It must not re-implement transformation logic or reach back into KCL/JSON.
- **CI harness** orchestrates all three in a temp dir. It may call into any layer's entry points but must never write to the real `~/`.

### Axis B — KCL module composition (inside the Source layer)

```
  _shared/  ◄────────  tool modules (*.k)  ◄────────  main.k
 (no deps)            (import _shared only)          (composition root:
                                                      imports every module)
```

- `_shared/` depends on nothing in the repo.
- Tool modules import **only** `_shared` (schemas/templates/mcp). A tool module importing another tool module is forbidden.
- `main.k` is the single composition root — the only file allowed to import multiple tool modules and wire them together.

**Data crossing boundaries**: KCL → Build crosses as **`out/config.json`** (plain JSON, the KCL evaluator's serialized output). Build → Deploy crosses as **TOML** (`global.toml`, `out/*.toml`) plus **Handlebars-templated files** with `{{ placeholder }}` markers resolved against `local.toml`. Secrets cross the Deploy boundary at runtime only (Keychain / Proton Pass → `post_deploy.sh`), never through committed files.

---

## 3. Boundary Rules

- **Source → Build boundary is a file, not a call.** The only contract is the shape of `out/config.json`. KCL writes it via `file.write()`; the Python converter reads it. Neither side imports the other. To change the contract, change the KCL schema *and* the converter together.
- **Static trees bypass the transform.** Content under `src/<tool>/` (nvim Lua, ghostty shaders, opencode prompts, …) is deployed directly by dotter as templates or symlinks. It is referenced by file mappings in the generated `global.toml`, but its *content* is never fed through `generate_from_kcl.py`. Do not route static config through KCL, and do not hand-author TOML that KCL should be generating.
- **Deploy communicates through generated config + hooks.** dotter reads `global.toml` (generated) merged with `local.toml` (user). The two deploy hooks are the only imperative glue: `pre_deploy.sh` runs the KCL build + pre-deploy validation; `post_deploy.sh` injects secrets and runs post-deploy validation.
- **Shared shell "DI".** Deploy/build shell scripts obtain shared behavior by sourcing `scripts/dotter/lib.sh` (`resolve_repo_root`, `resolve_python`, `ensure_dotter_dir`, `run_with_timeout`, `_ERR`/`_WARN`). New scripts reuse these helpers instead of re-implementing path resolution or logging.
- **Composition happens only in `main.k`.** Cross-module wiring is a Source-layer concern confined to the composition root. Tool modules expose one binding and stay unaware of each other.

---

## 4. Per-Layer Rules

### Layer 1 — Source (`src/`)

**What belongs here:**
- Hand-authored config data as KCL schemas + bindings (`src/*.k`).
- Shared type/template definitions in `src/_shared/`.
- Static config trees that deploy directly (`src/nvim/`, `src/ghostty/`, `src/opencode/`, …).
- Profile / platform / theme definitions and their `depends` inheritance.
- The `file.write()` calls in `main.k` that emit `out/config.json`.

**What does not belong here:**
- TOML output, dotter mechanics, or `~/` deploy paths.
- Secrets or per-machine values (those live in gitignored `local.k` → `local.toml`).
- Tool-module-to-tool-module imports (route shared types through `_shared`).
- Redeclaring variables already inherited via `depends` (dotter errors on duplicates).

**Common violations:**
- Editing `out/config.json`, `.dotter/global.toml`, or `out/*.toml` by hand instead of the KCL source.
- Hardcoding profile/platform/theme selection in `src/*.k` instead of `local.k`.
- A tool module importing another tool module instead of `_shared`.
- Wiring modules together somewhere other than `main.k`.

### Layer 2 — Build / Transform (`scripts/dotter/`)

**What belongs here:**
- `generate_from_kcl.py`: JSON (`out/config.json`) → TOML (`global.toml`, `out/*.toml`).
- Validators (`validate_generated.py`, `validate_toml.py`, `validate_jsonc*.py`, `validate_schema.sh`, …).
- Merge/patch helpers for runtime-rewritten configs (`merge_json_config.py`, `patch_opencode_secrets.py`).
- Shared shell helpers in `lib.sh`.

**What does not belong here:**
- Tool-specific config *values* — those come from `out/config.json`, never embedded in the converter.
- Reaching into `src/*.k` or re-evaluating KCL (the converter's only input is `out/config.json`).
- Knowledge of the user's home dir or deploy targets (that is Deploy's job).

**Common violations:**
- Special-casing a specific tool inside `generate_from_kcl.py` instead of expressing it in KCL.
- Silently continuing past a failed validation instead of `sys.exit(1)` with a diagnostic.
- Duplicating path-resolution logic instead of sourcing `lib.sh`.

### Layer 3 — Deploy (`.dotter/`, hooks, `scripts/secrets/`)

**What belongs here:**
- dotter file mappings (generated `global.toml`) + per-machine `local.toml`.
- `pre_deploy.sh` (run KCL + validate) and `post_deploy.sh` (inject secrets + validate).
- Secret sourcing scripts (`scripts/secrets/*.sh`) and the staging-file merge for runtime-rewritten apps.

**What does not belong here:**
- Transformation logic (belongs in Layer 2) or config data (belongs in Layer 1).
- Committed secrets — secrets are injected at deploy time from Keychain / Proton Pass only.
- Bypassing the hooks by deploying without running the KCL build.

**Common violations:**
- Writing generated config back into `src/` or committing `.dotter/global.toml` / `out/`.
- Re-implementing JSON→TOML conversion in a deploy hook.
- Committing a rendered staging file (`~/.cache/dotfiles/*.rendered.*`) or a resolved secret.

### CI harness (`scripts/dotter-ci/`, `.gitea/workflows/`)

**What belongs here:**
- Scripts that deploy the pipeline into a temp dir and assert validity (`test-nvim-startup.sh`, `validate-*.sh`, `test-apex-parser.sh`).
- The workflow definition (`validate-dotter.yml`) wiring those scripts together.

**What does not belong here:**
- Any write to the real `~/` or `.storage`-style live state.
- Business/config logic — CI only orchestrates and asserts against the other layers.

**Common violations:**
- A CI script mutating the developer's actual config instead of the temp deploy dir.
- Duplicating validation logic instead of invoking `scripts/dotter/validate_*`.

---

## 5. Key Flows

### Flow 1: Generated config (KCL path) — e.g. a new Starship setting

```
1. Source (src/starship.k)   Edit the typed StarshipConfig binding.
2. Source (src/main.k)        Already imports starship; on `kcl run`, file.write() emits out/config.json.
3. Build (generate_from_kcl)  Reads out/config.json → writes .dotter/global.toml + out/starship.toml.
4. Build (validate_*)         TOML parses, expected files exist, Handlebars blocks balanced → else exit 1.
5. Deploy (dotter + hooks)    pre_deploy runs 1–4; dotter renders/symlinks; post_deploy injects secrets + validates.
   Result: ~/.config/starship.toml deployed. src/ is the only thing a human edited.
```

### Flow 2: Static config (direct path) — e.g. a Neovim Lua change

```
1. Source (src/nvim/…)        Edit Lua directly. No KCL schema, no transform.
2. Source (src/main.k)        A file mapping in the KCL config points dotter at src/nvim/ (template or symlink).
3. Build                      generate_from_kcl emits the mapping into global.toml; it does NOT transform Lua content.
4. Deploy (dotter + hooks)    dotter deploys src/nvim/ to the target; post_deploy runs nvim --headless +qa! to validate.
   Result: Neovim config deployed as-authored; only the file mapping passed through the pipeline.
```

### Flow 3: Secret injection (runtime, Deploy-only)

```
1. Source                     local.k references a secret by name; global config carries a {{ placeholder }}.
2. Deploy (post_deploy.sh)    Sources scripts/secrets/*.sh → pulls value from Keychain / Proton Pass.
3. Deploy                     Substitutes into the deployed file (or merges the staging .rendered.* file).
   Result: secret present in ~/ only, never in the repo or out/.
```

---

## 6. Validation Checklist

STOP after generating or modifying each component. Verify ALL of the following before proceeding:

1. **LAYER PLACEMENT**: Is this change in the correct layer? Config *data* → Source (`src/`); JSON→TOML transform or validation → Build (`scripts/dotter/`); deploy mapping/hook/secret → Deploy. If it feels like it spans two, split it.
2. **SOURCE OF TRUTH**: Did you edit `src/` (KCL or a static tree) rather than any generated artifact (`out/`, `.dotter/global.toml`, `out/*.toml`)? Generated files are never hand-edited.
3. **PIPELINE DIRECTION**: Does data still flow Source → Build → Deploy only? No layer reaches backward (Build must not read `src/*.k`; Deploy must not re-transform).
4. **KCL COMPOSITION**: Do tool modules import only `_shared` (not each other), and is cross-module wiring confined to `main.k`?
5. **GENERATED vs STATIC**: Is tool config that *should* be typed KCL actually in KCL (not hand-written TOML), and is static content (Lua, shaders) left in its static tree (not forced through KCL)?
6. **SECRETS & PER-MACHINE**: Are secrets and per-machine values kept out of committed files (in `local.k` / Keychain / Proton Pass), never in `src/*.k` or `out/`?
7. **VALIDATION & FAIL-FAST**: If you added generated output or a deploy step, is there a corresponding validator, and does every failure path `exit 1` / `sys.exit(1)` with a diagnostic rather than continuing silently?
8. **SHARED HELPERS**: Do new shell scripts source `scripts/dotter/lib.sh` and reuse `resolve_*`/`_ERR`/`_WARN` instead of re-implementing path resolution or logging?

---

## 7. Anti-Patterns

After verifying the checklist above, scan output for these anti-patterns. If found, fix before presenting.

- [ ] **Editing generated output**: A change lands in `out/`, `.dotter/global.toml`, or `out/*.toml` → move the change to the KCL source (`src/*.k`) or the appropriate static tree and regenerate via `./deploy.sh`.
- [ ] **Backward pipeline dependency**: Build reads `src/*.k`, or Deploy re-implements transformation/reaches into JSON → restore the one-way flow: Build consumes only `out/config.json`; Deploy consumes only generated TOML + `local.toml`.
- [ ] **Tool-module cross-import**: One `src/<tool>.k` imports another tool module → route the shared type/template through `src/_shared/` and, if composition is needed, wire it in `main.k`.
- [ ] **Composition outside `main.k`**: Modules assembled/wired somewhere other than the composition root → relocate the wiring to `main.k`; keep tool modules exporting a single binding.
- [ ] **Hand-written TOML that KCL should own**: Typed, structured tool config authored as raw TOML/JSON instead of a KCL schema → backfill a KCL schema (see the schema-sourcing table in language-idioms) and generate it.
- [ ] **Static content forced through KCL**: Lua/shader/prompt content pushed through `generate_from_kcl.py` → keep it in its `src/<tool>/` static tree and let dotter deploy it directly; only the *file mapping* belongs in KCL.
- [ ] **Committed or hardcoded secrets / per-machine values**: A secret, token, or machine-specific path appears in `src/*.k` or a committed file → move it to `local.k` (gitignored) or a Keychain / Proton Pass lookup injected by `post_deploy.sh`.
- [ ] **Silent failure**: A validator or deploy step swallows an error and continues → fail fast with `exit 1` / `sys.exit(1)` and a stderr diagnostic (matches the repo's `set -eu` + `_ERR` convention).

---

## 8. Ambiguity Signals

These checks often have multiple valid outcomes. When you encounter one, present options rather than silently choosing.

- **KCL-generated vs static tree** for a new tool's config: highly structured, schema-backed config favors the KCL path; large freeform config (a Lua plugin setup, a shader) favors a static tree deployed directly. When it could go either way, ask.
- **Typed schema vs `{str: any}`** for a KCL tool module: if the tool publishes a JSON schema or thorough config docs, backfill a typed schema; if not, `{str: any}` may be acceptable. Surface the trade-off (see the schema-sourcing table in `language-idioms.md`).
- **Template (`{{ }}` substitution) vs symbolic (symlink)** for a dotter file mapping: templated when per-machine values or secrets must be injected; symbolic when the file is deployed verbatim. When a file has no placeholders but might later, flag the choice.
- **New shared schema in `_shared/` vs local to one module**: promote to `_shared/` only when two or more modules need it; a single-consumer type can stay local. If reuse is plausible-but-unproven, ask.
- **pre_deploy vs post_deploy** placement for a new deploy step: build/validate-before-deploy work → `pre_deploy.sh`; anything needing the files already in place or needing secrets → `post_deploy.sh`. When a step could run in either, confirm which invariant it depends on.

---

*Generated for the dotfiles repository on 2026-07-19. Style: Custom (config-generation pipeline).*
*Produced by the architecture-refiner skill.*
