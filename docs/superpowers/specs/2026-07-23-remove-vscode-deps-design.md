# Remove VS Code dependencies from dotfiles

**Date:** 2026-07-23
**Status:** Approved

## Goal

Completely remove VS Code from the dotfiles: stop installing the app and its
~70 extensions, and rework the three Neovim language servers that currently
scavenge their binaries out of `~/.vscode/extensions/` so they are sourced
independently. Finish with a one-time gated uninstall of VS Code from this
machine.

**Non-goals:** `vscode-langservers-extracted` (brew) and its
`vscode-json/html-language-server` binaries are name-only, not VS Code
dependencies — they stay. Historical backlog task files stay. VS Code app data
under `~/Library/Application Support/Code` is left untouched.

## Decisions made

- **Full removal** — cask, extension list, and LSP rework (not just
  "stop managing").
- **VSIX-as-archive is acceptable** — the Apex (jorje), Visualforce, and
  SonarLint servers only ship inside VSIX files; we download pinned VSIXes
  from **Open VSX** as plain zip archives (no VS Code app, no `code` CLI,
  no marketplace client). All three are confirmed available on Open VSX.
- **Uninstall from machine too**, gated on LSP validation passing first.
- **Mechanism: KCL pins + sync script** (matches `lmstudio_sync.sh` pattern),
  not a hardcoded script and not vendored jars.

## Version pins (from currently installed extensions)

| Server      | Extension                                    | Version | Target platform | Artifact checked                |
|-------------|----------------------------------------------|---------|-----------------|---------------------------------|
| Apex jorje  | `salesforce.salesforcedx-vscode-apex`        | 66.10.1 | universal       | `dist/apex-jorje-lsp.jar`       |
| Visualforce | `salesforce.salesforcedx-vscode-visualforce` | 66.10.1 | universal       | `dist/visualforceServer.js`     |
| SonarLint   | `sonarsource.sonarlint-vscode`               | 5.2.1   | `darwin-arm64`  | `server/sonarlint-ls.jar`       |

SonarLint publishes platform-specific VSIXes (embedded analyzers/JRE), so the
manifest carries an optional `target_platform`.

## Design

### 1. Declarative pins (KCL)

- `src/_shared/schemas.k`: remove `vscode_extensions?: [str]`; add
  `VsixLspServer` schema (`publisher`, `name`, `version`, `target_platform?`,
  `artifact_check`) and a `vsix_lsp_servers?: [VsixLspServer]` field.
- `src/packages.k`: remove the `visual-studio-code` cask, the entire
  `vscode_extensions` list, and the `vscode "..."` Brewfile comprehension;
  add the three pinned `vsix_lsp_servers` entries.

### 2. Generator

`scripts/dotter/generate_from_kcl.py`: delete the `vscode_extensions` →
Brewfile rendering; render `vsix_lsp_servers` to a JSON manifest under
`generated/` for the sync script.

### 3. Sync script + deploy wiring

New `scripts/lsp_vsix_sync.sh` (modeled on `lmstudio_sync.sh`):

- For each manifest entry, download
  `https://open-vsx.org/api/{publisher}/{name}/{version}/file/...`
  (with `targetPlatform` when set), unzip the `extension/` payload into
  `~/.local/share/lsp-servers/<name>/`.
- Drop a version marker file so re-runs are no-ops until a pin changes.
- Verify `artifact_check` exists after extraction; fail loudly if not.
- Wired into `scripts/post_deploy.sh` **before** the existing LSP validation
  block (~line 502). Offline with artifacts already present → warn, not fail.

### 4. Neovim configs

- `src/nvim/work/lsp/apex-language-server.lua`: replace the ~70-line
  multi-home `~/.vscode` discovery with one deterministic path under
  `~/.local/share/lsp-servers/`; keep the `NVIM_APEX_JAR_PATH` override and
  the missing-jar warning (now pointing at the sync script).
- `src/nvim/default/lua/config/lsp.lua`: Visualforce glob → new path.
- `src/nvim/work/lua/plugins/sonarlint.lua`: jar path → new path. Full-payload
  extraction preserves the `server/` + `analyzers/` sibling layout.

### 5. Validation scripts

- `scripts/dotter/validate_agent_lsp.py`: visualforce coverage glob → new path.
- `scripts/dotter/validate_lsp.lua`: visualforce install hint → "run
  scripts/lsp_vsix_sync.sh". `vscode-json/html-language-server` entries stay.

### 6. Reference sweep

- Delete dead `apex_lsp_jar_path` from `src/local.k` and `src/local.k.example`
  (no consumers anywhere in the repo).
- Update the VS Code mention in `src/aerospace/README.md`.
- Update `.agents/skills/dotfiles-kcl/SKILL.md` if it documents
  `vscode_extensions`.

### 7. One-time machine cleanup (ordered, gated)

1. Deploy; `lsp_vsix_sync.sh` populates `~/.local/share/lsp-servers/`.
2. Confirm LSP validation green (apex/visualforce/sonarlint attach from the
   new paths).
3. Only then: `brew uninstall --cask visual-studio-code` and delete
   `~/.vscode` — with explicit user confirmation at execution time.

`brew bundle install` has no `--cleanup`, so removing Brewfile entries alone
never uninstalls anything; the explicit step is required and is the only
destructive action.

### 8. Error handling & testing

- Sync script failures surface in post-deploy output before LSP validation
  runs, so a broken fetch is caught in the same deploy.
- Existing `validate_lsp.lua` headless live-attach test is the gate, plus a
  manual open of a `.cls` and `.page` file.
- Rollback safety: until step 7 runs, `~/.vscode` still exists, so nothing
  breaks mid-migration.
