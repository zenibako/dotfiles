# Remove VS Code Dependencies Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove VS Code (cask, ~70 extensions, and all `~/.vscode/extensions` lookups) from the dotfiles; source the Apex/Visualforce/SonarLint language servers from pinned Open VSX VSIX archives instead; add cssls + eslint servers; finish with a gated machine uninstall.

**Architecture:** Pins are declared in KCL (`src/packages.k`), rendered by the existing KCL pipeline to `out/.lsp_vsix_meta.json`, and consumed by a new POSIX-sh sync script (`scripts/lsp_vsix_sync.sh`, modeled on `scripts/lmstudio_sync.sh`) that unpacks VSIX zips into `~/.local/share/lsp-servers/<name>/`. Neovim configs point at those deterministic paths. The sync runs in `post_deploy.sh` before the LSP attach validation so a broken fetch surfaces in the same deploy.

**Tech Stack:** KCL, Python 3 (generator), POSIX sh, Lua (Neovim 0.11 `vim.lsp.Config`), Jujutsu for VC.

**Spec:** `docs/superpowers/specs/2026-07-23-remove-vscode-deps-design.md`

## Global Constraints

- Version pins, verbatim: `salesforce.salesforcedx-vscode-apex` **66.10.1**; `salesforce.salesforcedx-vscode-visualforce` **66.10.1**; `SonarSource.sonarlint-vscode` **5.2.1** with target platform **darwin-arm64**.
- Verified download URLs (HTTP 200 on 2026-07-23):
  - `https://open-vsx.org/api/salesforce/salesforcedx-vscode-apex/66.10.1/file/salesforce.salesforcedx-vscode-apex-66.10.1.vsix`
  - `https://open-vsx.org/api/salesforce/salesforcedx-vscode-visualforce/66.10.1/file/salesforce.salesforcedx-vscode-visualforce-66.10.1.vsix`
  - `https://open-vsx.org/api/SonarSource/sonarlint-vscode/darwin-arm64/5.2.1/file/SonarSource.sonarlint-vscode-5.2.1@darwin-arm64.vsix`
- Extraction target: `~/.local/share/lsp-servers/<extension-name>/` (the VSIX's `extension/` payload becomes that directory), version marker file `.vsix-version` inside it.
- Shell scripts are POSIX sh (`#!/bin/sh`, `set -eu`, no bashisms). `post_deploy.sh` uses the `_OK`/`_WARN`/`_GUIDE`/`_STEP` helpers from `scripts/dotter/lib.sh`.
- Lua indentation: `src/nvim/work/**` uses tabs; `src/nvim/default/**` uses 2 spaces. Match the file you are editing.
- Version control is **Jujutsu** (`jj`), not git. There is no staging — all files are auto-tracked. Commit with `jj commit -m "<msg>"`. Every commit message is conventional-commits style and ends with a blank line then `Co-authored-by: Claude Fable 5 <noreply@anthropic.com>`.
- `vscode-langservers-extracted` (brew formula) and its `vscode-json/html-language-server` binaries are **kept** — they are standalone, name-only.
- Task 9 contains destructive machine operations. NEVER run them without explicit user confirmation in the moment (per user's global CLAUDE.md rules).
- Repo root: `/Users/chandler.anderson/Projects/dotfiles`. Run all commands from there.

---

### Task 1: KCL pins + remove VS Code from package management

**Files:**
- Modify: `src/_shared/schemas.k:22-27` (PackageList), add schema after it
- Modify: `src/packages.k` (lines 8, 9-81, 90)
- Modify: `src/main.k` (after the `packages_meta` block, ~line 123)
- Modify: `scripts/dotter/generate_from_kcl.py:324-337` (`_write_brewfile`)

**Interfaces:**
- Produces: `out/.lsp_vsix_meta.json` with shape `{"servers": [{"namespace": str, "name": str, "version": str, "target_platform": str|absent, "artifact_check": str}]}`. Task 2's script consumes exactly this. The list is empty when `"work"` is not in `local.packages`.
- Produces: `out/Brewfile` with no `cask "visual-studio-code"` and no `vscode "..."` lines.

- [ ] **Step 1: Add `VsixLspServer` schema and drop `vscode_extensions` in `src/_shared/schemas.k`**

Replace lines 22–27:

```
schema PackageList:
    fedora?: [str]
    brew_taps?: [str]
    brew_formulae?: [str]
    brew_casks?: [str]
    vscode_extensions?: [str]
```

with:

```
schema PackageList:
    fedora?: [str]
    brew_taps?: [str]
    brew_formulae?: [str]
    brew_casks?: [str]

schema VsixLspServer:
    namespace: str
    name: str
    version: str
    target_platform?: str
    artifact_check: str
```

- [ ] **Step 2: Update `src/packages.k`**

Three edits:

1. In `brew_casks` (line 8), delete the entry `"visual-studio-code",` — the list becomes:

```
    brew_casks = ["android-commandlinetools","android-platform-tools","font-hack-nerd-font","geekbench","ghostty","gpg-suite","mitmproxy","quakenotch","salesforce-cli","temurin","zap","zerotier-one"]
```

2. Delete the entire `vscode_extensions = [ ... ]` block (lines 9–81, from `vscode_extensions = [` through its closing `]`).

3. Delete line 90 (`_brew_lines += ['vscode "' + ext + '"' for ext in packages.vscode_extensions]`) and append the pins block after the `PackageList` block (i.e. after the closing `}` of `packages = _shared.PackageList { ... }`):

```
# ── VSIX-distributed language servers ───────────────────────────────────
# Apex (jorje), Visualforce, and SonarLint ship only inside VS Code
# extension VSIXes. scripts/lsp_vsix_sync.sh fetches these pins from Open
# VSX as plain zip archives — no VS Code involved. Bump versions here.
vsix_lsp_servers: [_shared.VsixLspServer] = [
    _shared.VsixLspServer {
        namespace = "salesforce"
        name = "salesforcedx-vscode-apex"
        version = "66.10.1"
        artifact_check = "dist/apex-jorje-lsp.jar"
    }
    _shared.VsixLspServer {
        namespace = "salesforce"
        name = "salesforcedx-vscode-visualforce"
        version = "66.10.1"
        artifact_check = "dist/visualforceServer.js"
    }
    _shared.VsixLspServer {
        namespace = "SonarSource"
        name = "sonarlint-vscode"
        version = "5.2.1"
        target_platform = "darwin-arm64"
        artifact_check = "server/sonarlint-ls.jar"
    }
]
```

- [ ] **Step 3: Write the manifest from `src/main.k`**

Immediately after the `file.write("out/.packages_meta.json", ...)` line (~line 123), add:

```
# ── Write VSIX LSP server pins for scripts/lsp_vsix_sync.sh ────────────
# Work-profile only: all three servers (apex jorje, visualforce, sonarlint)
# are work-gated in Neovim, so other machines skip the ~150MB fetch.
vsix_meta = {
    "servers": packages_mod.vsix_lsp_servers if "work" in local.packages else []
}
file.write("out/.lsp_vsix_meta.json", json.encode(vsix_meta, indent=2))
```

(Colon-style dict entries, matching the `packages_meta` block above it; the conditional expression mirrors the `"mac" in local.packages` pattern already used at main.k:52.)

- [ ] **Step 4: Remove vscode lines from the Brewfile writer**

In `scripts/dotter/generate_from_kcl.py`, delete these two lines from `_write_brewfile` (lines 332–333):

```python
    for ext in data.get("vscode_extensions", []):
        lines.append(f'vscode "{ext}"')
```

- [ ] **Step 5: Regenerate and verify**

Run:
```sh
cd /Users/chandler.anderson/Projects/dotfiles && sh scripts/pre_deploy.sh
```
Expected: completes without KCL compile errors.

Then:
```sh
grep -E 'vscode|visual-studio-code' out/Brewfile
```
Expected: no output (exit 1).

```sh
python3 -c "import json; d=json.load(open('out/.lsp_vsix_meta.json')); print(len(d['servers'])); print([s['name'] for s in d['servers']])"
```
Expected: `3` and `['salesforcedx-vscode-apex', 'salesforcedx-vscode-visualforce', 'sonarlint-vscode']` (this machine's `local.k` has `"work"` in packages).

- [ ] **Step 6: Commit**

```sh
jj commit -m "feat(lsp): declare VSIX LSP server pins and drop VS Code from packages

Co-authored-by: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: `scripts/lsp_vsix_sync.sh`

**Files:**
- Create: `scripts/lsp_vsix_sync.sh` (mode 0755)

**Interfaces:**
- Consumes: `out/.lsp_vsix_meta.json` from Task 1 (shape documented there).
- Produces: `~/.local/share/lsp-servers/<name>/` populated with the VSIX `extension/` payload plus a `.vsix-version` marker containing `<version>` or `<version>@<target_platform>`. Exit codes: 0 = in sync (after syncing if needed), 1 = drift reported (`--check`) or a download/extract failure, 2 = cannot run (missing manifest/curl/unzip).
- Task 3 wires this into `post_deploy.sh`; Tasks 4+ rely on the populated paths.

- [ ] **Step 1: Write the script**

Create `scripts/lsp_vsix_sync.sh` with exactly:

```sh
#!/bin/sh
# Fetch the pinned VSIX-distributed language servers from Open VSX and unpack
# them into ~/.local/share/lsp-servers/<name>/ — replacing the old dependency
# on VS Code's ~/.vscode/extensions directory entirely.
#
# Pins live in src/packages.k (vsix_lsp_servers); KCL renders them to
# out/.lsp_vsix_meta.json at generation time. A .vsix is just a zip whose
# payload sits under extension/ — no VS Code, no `code` CLI, no marketplace
# client involved.
#
# Usage:
#   scripts/lsp_vsix_sync.sh          sync anything whose pin doesn't match
#   scripts/lsp_vsix_sync.sh --check  report drift only, exit 1 if any
set -eu

_REPO="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
_META="$_REPO/out/.lsp_vsix_meta.json"
_DEST="${LSP_SERVERS_DIR:-$HOME/.local/share/lsp-servers}"

[ -f "$_META" ] || { echo "missing $_META — run ./deploy.sh or scripts/pre_deploy.sh first" >&2; exit 2; }
command -v curl  >/dev/null 2>&1 || { echo "curl not found" >&2; exit 2; }
command -v unzip >/dev/null 2>&1 || { echo "unzip not found" >&2; exit 2; }

_CHECK=0
[ "${1:-}" = "--check" ] && _CHECK=1

# One tab-separated row per server: name version target url artifact
_rows="$(mktemp)"
python3 - "$_META" > "$_rows" <<'PY'
import json, sys
meta = json.load(open(sys.argv[1]))
for s in meta.get("servers", []):
    ns, name, ver = s["namespace"], s["name"], s["version"]
    tp = s.get("target_platform") or ""
    if tp:
        url = f"https://open-vsx.org/api/{ns}/{name}/{tp}/{ver}/file/{ns}.{name}-{ver}@{tp}.vsix"
    else:
        url = f"https://open-vsx.org/api/{ns}/{name}/{ver}/file/{ns}.{name}-{ver}.vsix"
    print("\t".join([name, ver, tp or "-", url, s["artifact_check"]]))
PY

_drift=0
_fail=0
_TAB="$(printf '\t')"
while IFS="$_TAB" read -r _name _ver _tp _url _artifact; do
  [ "$_tp" = "-" ] && _tp=""
  _want="$_ver${_tp:+@$_tp}"
  _dir="$_DEST/$_name"
  _have="$(cat "$_dir/.vsix-version" 2>/dev/null || true)"

  if [ "$_have" = "$_want" ] && [ -e "$_dir/$_artifact" ]; then
    echo "  ok       $_name  ($_want)"
    continue
  fi

  _drift=1
  if [ "$_CHECK" -eq 1 ]; then
    echo "  STALE    $_name  have '${_have:-none}', want '$_want'"
    continue
  fi

  echo "  syncing  $_name -> $_want"
  _tmpd="$(mktemp -d)"
  if ! curl -fsSL --retry 2 -o "$_tmpd/pkg.vsix" "$_url"; then
    echo "  FAILED   $_name — download error: $_url" >&2
    _fail=1; rm -rf "$_tmpd"; continue
  fi
  if ! unzip -q "$_tmpd/pkg.vsix" 'extension/*' -d "$_tmpd"; then
    echo "  FAILED   $_name — unzip error" >&2
    _fail=1; rm -rf "$_tmpd"; continue
  fi
  if [ ! -e "$_tmpd/extension/$_artifact" ]; then
    echo "  FAILED   $_name — $_artifact missing from VSIX" >&2
    _fail=1; rm -rf "$_tmpd"; continue
  fi
  mkdir -p "$_DEST"
  rm -rf "$_dir"
  mv "$_tmpd/extension" "$_dir"
  printf '%s\n' "$_want" > "$_dir/.vsix-version"
  rm -rf "$_tmpd"
  echo "  synced   $_name  ($_want)"
done < "$_rows"
rm -f "$_rows"

if [ "$_fail" -ne 0 ]; then
  exit 1
fi
if [ "$_CHECK" -eq 1 ] && [ "$_drift" -ne 0 ]; then
  echo
  echo "Run 'scripts/lsp_vsix_sync.sh' to sync."
  exit 1
fi
echo "LSP VSIX servers match the pinned versions."
```

Then: `chmod +x scripts/lsp_vsix_sync.sh`

- [ ] **Step 2: Red — check mode reports drift before anything is fetched**

```sh
sh scripts/lsp_vsix_sync.sh --check; echo "exit=$?"
```
Expected: three `STALE ... have 'none'` lines and `exit=1` (nothing under `~/.local/share/lsp-servers/` yet).

- [ ] **Step 3: Green — sync populates the artifacts**

```sh
sh scripts/lsp_vsix_sync.sh; echo "exit=$?"
```
Expected: three `syncing`/`synced` lines, final `LSP VSIX servers match the pinned versions.`, `exit=0`. (SonarLint is ~100MB; allow a few minutes.)

Verify artifacts:
```sh
ls -l ~/.local/share/lsp-servers/salesforcedx-vscode-apex/dist/apex-jorje-lsp.jar \
      ~/.local/share/lsp-servers/salesforcedx-vscode-visualforce/dist/visualforceServer.js \
      ~/.local/share/lsp-servers/sonarlint-vscode/server/sonarlint-ls.jar
cat ~/.local/share/lsp-servers/sonarlint-vscode/.vsix-version
```
Expected: all three files exist; marker prints `5.2.1@darwin-arm64`.

- [ ] **Step 4: Idempotence — second run is a no-op**

```sh
sh scripts/lsp_vsix_sync.sh; echo "exit=$?"
```
Expected: three `ok` lines (no downloads), `exit=0`.

- [ ] **Step 5: Commit**

```sh
jj commit -m "feat(lsp): fetch pinned VSIX language servers from Open VSX

Co-authored-by: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Wire the sync into `post_deploy.sh`

**Files:**
- Modify: `scripts/post_deploy.sh` (insert before the `# ── Neovim startup test ──` section, currently ~line 487)

**Interfaces:**
- Consumes: `scripts/lsp_vsix_sync.sh` exit codes from Task 2.
- Produces: deploy-time `_OK`/`_WARN` output; runs BEFORE the Neovim LSP attach validation so missing artifacts show up in the same deploy.

- [ ] **Step 1: Insert the sync block**

In `scripts/post_deploy.sh`, directly above the line `# ── Neovim startup test ──────────────────────────────────────────────────`, insert:

```sh
# ── VSIX-distributed LSP servers ──────────────────────────────────────────
# Apex (jorje), Visualforce, and SonarLint ship only inside VS Code extension
# VSIXes. scripts/lsp_vsix_sync.sh fetches the pinned versions from Open VSX
# (plain zip archives — no VS Code involved) into ~/.local/share/lsp-servers/,
# which is where the Neovim configs point. Run before the LSP attach
# validation below so a broken fetch is visible in the same deploy. Advisory:
# offline with artifacts already present exits 0; a real failure warns here
# and then shows concretely as a missing server in the validation output.
_vsix_sync="$REPO_ROOT/scripts/lsp_vsix_sync.sh"
if [ -x "$_vsix_sync" ]; then
  _vsix_rc=0
  _vsix_out="$("$_vsix_sync" 2>&1)" || _vsix_rc=$?
  if [ "$_vsix_rc" -eq 0 ]; then
    _OK "VSIX LSP servers match the pinned versions"
  else
    printf '%s\n' "$_vsix_out" | grep -E '^  (STALE|FAILED)' | while read -r _l; do
      _WARN "VSIX LSP: $_l"
    done
    _GUIDE "scripts/lsp_vsix_sync.sh"
  fi
fi
unset _vsix_sync _vsix_out _vsix_rc
```

- [ ] **Step 2: Syntax check**

```sh
sh -n scripts/post_deploy.sh && echo OK
```
Expected: `OK`.

- [ ] **Step 3: Commit**

```sh
jj commit -m "feat(deploy): sync VSIX LSP servers before LSP validation

Co-authored-by: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Point Neovim at the VSIX-managed servers

**Files:**
- Modify: `src/nvim/work/lsp/apex-language-server.lua` (replace lines 1–114; keep 116–143 unchanged)
- Modify: `src/nvim/default/lua/config/lsp.lua:5-12`
- Modify: `src/nvim/work/lua/plugins/sonarlint.lua:1-3`

**Interfaces:**
- Consumes: paths produced by Task 2 (`~/.local/share/lsp-servers/...`).
- Produces: `apex_jar_path`, `visualforce_server`, `sonarlint_jar` locals feeding the unchanged server-launch code. `NVIM_APEX_JAR_PATH` env override is preserved.

- [ ] **Step 1: Rewrite discovery in `apex-language-server.lua`**

Replace everything from line 1 through line 114 (i.e. everything above `local config = {`) with (tabs for indentation):

```lua
-- Apex jorje LSP. The jar is unpacked from the pinned Salesforce VSIX by
-- scripts/lsp_vsix_sync.sh (dotfiles repo) into ~/.local/share/lsp-servers/ —
-- VS Code is not involved and need not be installed.
-- Override: set $NVIM_APEX_JAR_PATH to skip the managed path entirely.
local MANAGED_JAR = "~/.local/share/lsp-servers/salesforcedx-vscode-apex/dist/apex-jorje-lsp.jar"

local function discover_apex_jar()
	local override = os.getenv("NVIM_APEX_JAR_PATH")
	if override and override ~= "" then
		return override
	end
	local jar = vim.fn.expand(MANAGED_JAR)
	if vim.fn.filereadable(jar) == 1 then
		return jar
	end
	return nil
end

local apex_jar_path = discover_apex_jar()

-- Warn once per session when opening an Apex file if the JAR is missing.
if not apex_jar_path then
	vim.api.nvim_create_autocmd("FileType", {
		pattern = { "apex", "java", "trigger", "apexcode" },
		callback = function()
			vim.notify(
				"Apex Language Server: apex-jorje-lsp.jar not found.\n"
					.. "Expected: " .. MANAGED_JAR .. "\n\n"
					.. "Fetch it: run scripts/lsp_vsix_sync.sh in the dotfiles repo.\n"
					.. "Override: export NVIM_APEX_JAR_PATH=/path/to/apex-jorje-lsp.jar",
				vim.log.levels.WARN,
				{ title = "Apex LSP" }
			)
		end,
		once = true,
	})
end
```

Lines from `local config = {` to the end of the file stay byte-identical.

- [ ] **Step 2: Update the Visualforce block in `config/lsp.lua`**

Replace lines 5–10:

```lua
local visualforce_ext = vim.fn.glob(vim.fn.expand("~/.vscode/extensions/salesforce.salesforcedx-vscode-visualforce-*/dist/visualforceServer.js"))

-- Use the VS Code Visualforce server when the extension is installed locally.
-- filetypes is REQUIRED: an enabled config without it attaches to every buffer
-- (vim.lsp.enable treats nil filetypes as "all filetypes").
if visualforce_ext ~= "" then
```

with:

```lua
local visualforce_server = vim.fn.expand("~/.local/share/lsp-servers/salesforcedx-vscode-visualforce/dist/visualforceServer.js")

-- Use the VSIX-unpacked Visualforce server when lsp_vsix_sync.sh has fetched
-- it. filetypes is REQUIRED: an enabled config without it attaches to every
-- buffer (vim.lsp.enable treats nil filetypes as "all filetypes").
if vim.fn.filereadable(visualforce_server) == 1 then
```

and on line 12 change `cmd = { "node", visualforce_ext, "--stdio" },` to `cmd = { "node", visualforce_server, "--stdio" },`.

Also update the comment on line 76–77 from `(visualforce is enabled above, only when the VS Code extension provides its server)` to `(visualforce is enabled above, only when lsp_vsix_sync.sh has provided its server)`.

- [ ] **Step 3: Update `sonarlint.lua`**

Replace lines 1–3:

```lua
-- Optional SonarLint integration (SonarQube rules in real-time).
-- Auto-detects the SonarLint VS Code extension server JAR, similar to visualforce-language-server.
local sonarlint_jar = vim.fn.glob(vim.fn.expand("~/.vscode/extensions/sonarsource.sonarlint-vscode-*/server/sonarlint-ls.jar"))
```

with (tabs preserved in the rest of the file):

```lua
-- Optional SonarLint integration (SonarQube rules in real-time).
-- Uses the VSIX-unpacked server from scripts/lsp_vsix_sync.sh; the analyzers/
-- directory sits beside server/ exactly as in the extension layout.
local sonarlint_jar = vim.fn.expand("~/.local/share/lsp-servers/sonarlint-vscode/server/sonarlint-ls.jar")
```

and change line 5 from `if sonarlint_jar ~= "" then` to `if vim.fn.filereadable(sonarlint_jar) == 1 then`.

- [ ] **Step 4: Lua syntax check**

```sh
luac -p src/nvim/work/lsp/apex-language-server.lua src/nvim/work/lua/plugins/sonarlint.lua && echo OK
```
Expected: `OK`. (`config/lsp.lua` contains Handlebars markers, so it can't be luac'd raw — it is validated post-deploy by the existing "All Lua files valid" step.)

- [ ] **Step 5: Commit**

```sh
jj commit -m "feat(nvim): point apex, visualforce, and sonarlint at VSIX-managed servers

Co-authored-by: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: Add cssls and eslint servers

**Files:**
- Create: `src/nvim/default/lsp/cssls.lua`
- Create: `src/nvim/default/lsp/eslint.lua`
- Modify: `src/nvim/default/lua/config/lsp.lua:95-108` (default enable list)

**Interfaces:**
- Consumes: `vscode-css-language-server` / `vscode-eslint-language-server` binaries (already installed via the `vscode-langservers-extracted` brew formula).
- Produces: enabled config names `cssls` and `eslint` — Task 6 keys its validation entries on exactly these names.

- [ ] **Step 1: Create `src/nvim/default/lsp/cssls.lua`** (2-space indent)

```lua
---@type vim.lsp.Config
return {
  cmd = { "vscode-css-language-server", "--stdio" },
  filetypes = { "css", "scss", "less" },
  root_markers = { "package.json", ".git" },
  single_file_support = true,
  init_options = { provideFormatter = true },
  settings = {
    css = { validate = true },
    scss = { validate = true },
    less = { validate = true },
  },
}
```

- [ ] **Step 2: Create `src/nvim/default/lsp/eslint.lua`** (2-space indent)

```lua
-- Diagnostics and code actions from the project's own eslint config.
-- Rooted on eslint config files only, so it stays silent in projects
-- without one. Formatting stays with prettier (format = false).
---@type vim.lsp.Config
return {
  cmd = { "vscode-eslint-language-server", "--stdio" },
  filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact", "vue", "astro" },
  root_markers = {
    "eslint.config.js",
    "eslint.config.mjs",
    "eslint.config.cjs",
    ".eslintrc.js",
    ".eslintrc.cjs",
    ".eslintrc.json",
    ".eslintrc.yaml",
    ".eslintrc.yml",
  },
  -- The server errors without workspaceFolder in settings (matches
  -- nvim-lspconfig's eslint before_init).
  before_init = function(_, config)
    local root = config.root_dir
    if root then
      config.settings = config.settings or {}
      config.settings.workspaceFolder = {
        uri = root,
        name = vim.fn.fnamemodify(root, ":t"),
      }
    end
  end,
  settings = {
    validate = "on",
    useESLintClass = false,
    experimental = { useFlatConfig = false },
    codeActionOnSave = { enable = false, mode = "all" },
    format = false,
    quiet = false,
    onIgnoredFiles = "off",
    rulesCustomizations = {},
    run = "onType",
    problems = { shortenToSingleLine = false },
    nodePath = "",
    workingDirectory = { mode = "location" },
    codeAction = {
      disableRuleComment = { enable = true, location = "separateLine" },
      showDocumentation = { enable = true },
    },
  },
}
```

- [ ] **Step 3: Enable both in the default list**

In `src/nvim/default/lua/config/lsp.lua`, the default `vim.lsp.enable` block becomes (alphabetical):

```lua
-- Default LSP servers (configs in src/nvim/default/lsp/ — always available).
vim.lsp.enable({
  "basedpyright",
  "cssls",
  "cue",
  "eslint",
  "gopls",
  "html",
  "jsonls",
  "kcl-lsp",
  "kotlin-lsp",
  "lua-ls",
  "pkl-lsp",
  "starlark-rust",
  "taplo",
  "yamlls",
})
```

- [ ] **Step 4: Lua syntax check**

```sh
luac -p src/nvim/default/lsp/cssls.lua src/nvim/default/lsp/eslint.lua && echo OK
```
Expected: `OK`.

- [ ] **Step 5: Commit**

```sh
jj commit -m "feat(nvim): add cssls and eslint from vscode-langservers-extracted

Co-authored-by: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: Update validation scripts

**Files:**
- Modify: `scripts/dotter/validate_lsp.lua` (install_hints ~lines 43–66; lsp_tests table)
- Modify: `scripts/dotter/validate_agent_lsp.py:327-330`

**Interfaces:**
- Consumes: config names `cssls`/`eslint` (Task 5), path `~/.local/share/lsp-servers/salesforcedx-vscode-visualforce/dist/visualforceServer.js` (Task 2).
- Produces: attach-test coverage for the new servers; corrected install hints.

- [ ] **Step 1: Update install hints in `validate_lsp.lua`**

Change line 57 (apex) and line 61 (visualforce) to:

```lua
  ["apex-language-server"] = { binary = "apex-jorje-lsp.jar", manager = "vsix", cmd = "scripts/lsp_vsix_sync.sh (dotfiles repo)" },
```

```lua
  ["visualforce-language-server"] = { binary = "visualforceServer.js", manager = "vsix", cmd = "scripts/lsp_vsix_sync.sh (dotfiles repo)" },
```

and add two entries after the existing `vscode-json-language-server` line (line 49):

```lua
  ["vscode-css-language-server"] = { binary = "vscode-langservers-extracted", manager = "brew", cmd = "brew install vscode-langservers-extracted" },
  ["vscode-eslint-language-server"] = { binary = "vscode-langservers-extracted", manager = "brew", cmd = "brew install vscode-langservers-extracted" },
```

- [ ] **Step 2: Add attach-test entries to `lsp_tests`**

Insert after the `html = { ... }` entry:

```lua
  cssls = {
    filetype = "css",
    filename = "test.css",
    content = "body { color: red; }\n",
  },
  eslint = {
    filetype = "javascript",
    filename = "test.js",
    content = "const x = 1\nconsole.log(x)\n",
    root_markers = { ".eslintrc.json" },
    root_content = '{ "root": true, "rules": {} }\n',
  },
```

(Keys must match the enabled config names `cssls`/`eslint` exactly — the runner looks up `lsp_tests[lsp_name]`. The eslint test workspace has no `node_modules`, so the server may emit a library-resolution notice after attaching; attach success is what's scored. If a stray line shows up in deploy output, Task 8 Step 3 handles it.)

- [ ] **Step 3: Update the Visualforce coverage check in `validate_agent_lsp.py`**

Replace lines 327–330:

```python
    if glob.glob(
        str(HOME / ".vscode/extensions/salesforce.salesforcedx-vscode-visualforce-*/dist/visualforceServer.js")
    ):
        covered["visualforce-language-server"] = "visualforce"
```

with:

```python
    if (HOME / ".local/share/lsp-servers/salesforcedx-vscode-visualforce/dist/visualforceServer.js").exists():
        covered["visualforce-language-server"] = "visualforce"
```

- [ ] **Step 4: Syntax checks**

```sh
luac -p scripts/dotter/validate_lsp.lua && python3 -m py_compile scripts/dotter/validate_agent_lsp.py && echo OK
```
Expected: `OK`.

- [ ] **Step 5: Commit**

```sh
jj commit -m "chore(validate): cover VSIX-managed, cssls, and eslint servers

Co-authored-by: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: Sweep remaining VS Code references

**Files:**
- Modify: `src/local.k` (line 12 — gitignored, edit directly)
- Modify: `src/local.k.example` (line 28)
- Modify: `src/aerospace/README.md` (line ~97)

**Interfaces:** none — cleanup only.

- [ ] **Step 1: Delete `apex_lsp_jar_path`**

Remove line 12 from `src/local.k` (`apex_lsp_jar_path = "/Users/chandler.anderson/.vscode/extensions/..."`) and line 28 from `src/local.k.example` (`apex_lsp_jar_path = ""`). The variable has zero consumers (verified 2026-07-23).

- [ ] **Step 2: Update `src/aerospace/README.md`**

In the item 7 list of installed-but-unassigned apps, remove `VS Code, ` (it will no longer be installed):

```
7. **Workspace 5 is a free slot** — no apps, no purpose yet. Candidates from
   installed-but-unassigned apps: Claude Desktop, Postman, Safari,
   GitLab PWA, YouTube / YouTube Music PWAs.
```

- [ ] **Step 3: Verify nothing real remains**

```sh
grep -rin --exclude-dir=.git -E '\.vscode/extensions|visual-studio-code|vscode_extensions' \
  src scripts deploy.sh init.sh .agents 2>/dev/null
```
Expected: no output. (Mentions of `vscode-langservers-extracted`, `vscode-html/json/css/eslint-language-server`, historical backlog tasks, and the specs/plans docs are fine and expected from the broader pattern — this grep targets only the real dependencies.) If anything else surfaces (e.g. a "VS Code" phrase in `.agents/skills/dotfiles-kcl/SKILL.md`), fix it in the same spirit: reference the sync script instead.

- [ ] **Step 4: Regenerate to prove `local.k` still compiles**

```sh
sh scripts/pre_deploy.sh && echo OK
```
Expected: `OK`.

- [ ] **Step 5: Commit**

```sh
jj commit -m "chore: drop remaining VS Code references

Co-authored-by: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 8: Full deploy + validation gate

**Files:** none created; possibly modify `scripts/post_deploy.sh` (LSP_FILTERS heredoc, ~line 508) if eslint emits stray lines.

**Interfaces:**
- Consumes: everything above.
- Produces: the green gate Task 9 requires. Raw log at `~/.cache/dotfiles/logs/lsp-validation-raw.log`.

- [ ] **Step 1: Deploy**

```sh
./deploy.sh
```
Expected in output: `✓ VSIX LSP servers match the pinned versions`, Neovim startup passes, and the LSP attach validation runs.

- [ ] **Step 2: Verify the attach results**

In the validation output (or `~/.cache/dotfiles/logs/lsp-validation-raw.log`): `apex-language-server`, `visualforce-language-server`, `cssls`, and `eslint` each show `✓` (attached). Also confirm SonarLint started from the new jar:

```sh
grep -c "SonarQube language server is ready" ~/.cache/dotfiles/logs/lsp-validation-raw.log
```
Expected: `1` or more.

- [ ] **Step 3: (Only if needed) silence new eslint noise**

If the deploy output flagged "unexpected line(s) during LSP validation" and the stray log shows eslint library-resolution messages, add each observed literal line to the `LSP_FILTERS` heredoc in `scripts/post_deploy.sh` (one per line, exact text), then re-run `./deploy.sh` to confirm clean. Commit only if this step changed anything:

```sh
jj commit -m "chore(deploy): filter eslint validation noise

Co-authored-by: Claude Fable 5 <noreply@anthropic.com>"
```

- [ ] **Step 4: Advance the bookmark**

```sh
jj bookmark move main --to @- && jj log --git -n 3
```
Expected: `main` points at the last commit of this work.

---

### Task 9: Gated machine uninstall (DESTRUCTIVE — user confirmation required)

**Files:** none — machine state only.

**Interfaces:**
- Consumes: Task 8's green gate. Do NOT start this task if Task 8 failed.

- [ ] **Step 1: Show current state and ask the user**

```sh
brew list --cask | grep visual-studio-code
du -sh ~/.vscode 2>/dev/null
ls ~/.local/share/lsp-servers/
```

Present to the user: what will be removed (`visual-studio-code` cask, `~/.vscode` including its extensions), what is kept (`~/Library/Application Support/Code` app data), and that the LSP validation passed from the new paths. **Wait for explicit confirmation. Do not proceed without it.**

- [ ] **Step 2: Uninstall (after confirmation only)**

```sh
osascript -e 'quit app "Visual Studio Code"' 2>/dev/null || true
brew uninstall --cask visual-studio-code
rm -rf ~/.vscode
```
Expected: cask uninstalls cleanly; `~/.vscode` gone.

- [ ] **Step 3: Post-removal smoke test**

```sh
sh scripts/lsp_vsix_sync.sh --check
run_nvim_check() { nvim --headless -c "luafile scripts/dotter/validate_lsp.lua" -c "qa!" 2>&1 | grep -E 'apex-language-server|visualforce|cssls|eslint'; }
run_nvim_check
```
Expected: sync check exits 0 (`ok` on all three); apex/visualforce/cssls/eslint still `✓` with `~/.vscode` gone — proving no residual dependency.

- [ ] **Step 4: Report completion**

No commit (no repo changes). Summarize: VS Code uninstalled, all LSPs green from `~/.local/share/lsp-servers/`, Brewfile no longer manages VS Code on any machine.
