#!/usr/bin/env lua
-- validate_lsp.lua: Validate Neovim LSP attachments after deploy
-- Usage: nvim --headless -c "luafile validate_lsp.lua" -c "qa!"
--
-- This checks that enabled LSPs have their binaries available and can attach
-- to test buffers, then runs the nvim-lint linter validation (sf code-analyzer
-- against an apex fixture).
--
-- Output format matches scripts/dotter/lib.sh conventions (2-space indent,
-- ✓/⚠/⊘ glyphs). This script emits NO ANSI codes itself — headless nvim
-- writes to stderr, which post_deploy.sh captures, strips, filters, and then
-- colorizes with the lib.sh COLOR_* palette (see the LSP validation block).

local test_dir = vim.fn.tempname() .. "-nvim-lsp-test"
vim.fn.mkdir(test_dir, "p")

-- Suppress known non-fatal plugin/LSP chatter during headless init. Messages
-- suppressed here are dropped before they ever reach stderr; noise that
-- bypasses vim.notify is instead filtered by post_deploy.sh, which also keeps
-- the raw stderr at ~/.cache/dotfiles/logs/lsp-validation-raw.log.
local orig_notify = vim.notify
vim.notify = function(msg, level, opts)
  if type(msg) == "string" and (
    msg:match("Cannot read properties of null")
    or msg:match("vim%.schedule callback")
    or msg:match("RPC%[Error%]")
    or msg:match("Request initialize failed")
    -- sf.nvim probes <root>/sf_cache/test_result.json on apex buffers; the
    -- throwaway test roots never have it.
    or msg:match("sf_cache")
    -- sonarlint.nvim announces readiness; lwc logs on shutdown via
    -- window/showMessage when the test buffer is deleted.
    or msg:match("SonarQube language server is ready")
    or msg:match("LWC Language Server shutting down")
  ) then
    return
  end
  orig_notify(msg, level, opts)
end

-- Install command hints per LSP binary name.
-- Format: { binary = "pkg-name", manager = "brew/npm/pipx/go/gem/...", cmd = "install command" }
local install_hints = {
  ["gopls"]                = { binary = "gopls", manager = "go", cmd = "go install golang.org/x/tools/gopls@latest" },
  ["basedpyright-langserver"] = { binary = "basedpyright", manager = "pipx", cmd = "pipx install basedpyright" },
  ["pyright-langserver"]   = { binary = "pyright", manager = "pipx", cmd = "pipx install pyright" },
  ["lua-language-server"]  = { binary = "lua-language-server", manager = "brew", cmd = "brew install lua-language-server" },
  ["vscode-html-language-server"] = { binary = "vscode-langservers-extracted", manager = "npm", cmd = "npm install -g vscode-langservers-extracted" },
  ["vscode-json-language-server"] = { binary = "vscode-langservers-extracted", manager = "npm", cmd = "npm install -g vscode-langservers-extracted" },
  ["yaml-language-server"] = { binary = "yaml-language-server", manager = "npm", cmd = "npm install -g yaml-language-server" },
  ["taplo"]                = { binary = "taplo", manager = "brew", cmd = "brew install taplo" },
  ["pkl-lsp"]              = { binary = "pkl-lsp", manager = "brew", cmd = "brew install pkl-lsp" },
  ["typescript-language-server"] = { binary = "typescript-language-server", manager = "npm", cmd = "npm install -g typescript-language-server" },
  ["cue"]                  = { binary = "cue", manager = "brew", cmd = "brew install cue-lang/tap/cue" },
  ["starlark"]             = { binary = "starlark", manager = "brew", cmd = "brew install starlark-rust" },
  ["sourcekit-lsp"]        = { binary = "sourcekit-lsp", manager = "xcode", cmd = "Install Xcode Command Line Tools: xcode-select --install" },
  ["apex-language-server"] = { binary = "apex-jorje-lsp.jar", manager = "mason", cmd = ":MasonInstall apex-language-server (in Neovim)" },
  ["gitlab-ci-ls"]         = { binary = "gitlab-ci-ls", manager = "cargo", cmd = "cargo install gitlab-ci-ls" },
  ["lwc-language-server"]  = { binary = "lwc-language-server", manager = "npm", cmd = "npm install -g @salesforce/lwc-language-server" },
  ["terraform-ls"]         = { binary = "terraform-ls", manager = "brew", cmd = "brew install hashicorp/tap/terraform-ls" },
  ["visualforce-language-server"] = { binary = "visualforceServer.js", manager = "vscode", cmd = "Install Salesforce Extension Pack in VS Code" },
  ["kcl-language-server"]  = { binary = "kcl-language-server", manager = "brew", cmd = "brew install kcl-lang/tap/kcl-lsp" },
  ["kotlin-lsp"]           = { binary = "kotlin-lsp", manager = "brew", cmd = "brew install jetbrains/kotlin-kotlinlang/kotlin-lsp" },
  ["apex_ls"]              = { binary = "apex-ls-stdio.sh", manager = "local", cmd = "Local prototype — see ~/.local/share/apex-language-server/" },
  ["tsc"]                  = { binary = "typescript", manager = "npm", cmd = "npm install -g typescript" },
}

-- Test file definitions per LSP
local lsp_tests = {
  gopls = {
    filetype = "go",
    filename = "main.go",
    content = "package main\n\nfunc main() {}\n",
    root_markers = { "go.mod" },
    root_content = "module test\n\ngo 1.21\n",
  },
  basedpyright = {
    filetype = "python",
    filename = "main.py",
    content = "def main():\n    pass\n",
    root_markers = { "pyproject.toml" },
    root_content = "[tool.basedpyright]\n",
  },
  ["lua-ls"] = {
    filetype = "lua",
    filename = "test.lua",
    content = "local M = {}\nreturn M\n",
  },
  html = {
    filetype = "html",
    filename = "test.html",
    content = "<!DOCTYPE html>\n<html><body></body></html>\n",
  },
  jsonls = {
    filetype = "json",
    filename = "test.json",
    content = '{"key": "value"}\n',
  },
  yamlls = {
    filetype = "yaml",
    filename = "test.yaml",
    content = "key: value\n",
  },
  taplo = {
    filetype = "toml",
    filename = "test.toml",
    content = "key = \"value\"\n",
  },
  ["pkl-lsp"] = {
    filetype = "pkl",
    filename = "test.pkl",
    content = "bird {\n  name = \"Dodo\"\n}\n",
    root_markers = { "PklProject" },
    root_content = "amends \"pkl:Project\"\n",
  },
  ["kcl-lsp"] = {
    filetype = "kcl",
    filename = "test.k",
    content = "schema Test:\n    name: str\n\ntest = Test {name = \"hello\"}\n",
    root_markers = { "kcl.mod" },
    root_content = "[package]\nname = \"test\"\nedition = \"0.9.0\"\nversion = \"0.0.1\"\n",
  },
  cue = {
    filetype = "cue",
    filename = "test.cue",
    content = "package test\n\n// test comment\n",
    root_markers = { "cue.mod" },
    root_content = "",
  },
  ["starlark-rust"] = {
    filetype = "starlark",
    filename = "test.star",
    content = "def hello():\n    return \"world\"\n",
  },
  ["sourcekit-lsp"] = {
    filetype = "swift",
    filename = "test.swift",
    content = 'import Foundation\nprint("hello")\n',
  },
  ["jinja-lsp"] = {
    filetype = "jinja",
    filename = "test.jinja",
    content = "{{ variable }}\n",
  },
  -- Keyed by the enabled config name (kotlin-lsp), NOT the filetype (kotlin);
  -- the lookup is lsp_tests[lsp_name], so a "kotlin" key would never match and
  -- the server would fall through to "no test mapping".
  ["kotlin-lsp"] = {
    filetype = "kotlin",
    filename = "MyClass.kt",
    content = 'interface MyInterface\n\ninterface Impl : MyInterface {}\n\nobject impl : Impl {}\n',
  },
  ["apex-language-server"] = {
    filetype = "apex",
    filename = "Test.cls",
    content = "public class Test {}\n",
  },
  -- Local prototype server (forcedotcom/apex-language-support), enabled by
  -- ~/.config/nvim/plugin/apex_ls_prototype.lua only when its wrapper exists.
  apex_ls = {
    filetype = "apex",
    filename = "Test.cls",
    content = "public class Test {}\n",
    root_markers = { "sfdx-project.json" },
    root_content = '{ "packageDirectories": [{ "path": "force-app", "default": true }] }\n',
    -- Node server; needs longer than the default 2s grace after null-ls attaches.
    grace_period_ms = 15000,
  },
  ["gitlab-ci-ls"] = {
    filetype = "yaml.gitlab",
    filename = ".gitlab-ci.yml",
    content = "stages:\n  - build\n",
  },
  ["lwc-language-server"] = {
    filetype = "javascript",
    filename = "lwc/myComponent/myComponent.js",
    content = "import { LightningElement } from 'lwc';\nexport default class MyComponent extends LightningElement {}\n",
    -- The lwc-lsp-wrapper.sh gates on $PWD/.sf existing (spawned with nvim's
    -- cwd), so the test must create .sf/ AND chdir into the test root.
    root_markers = { "sfdx-project.json", "force-app/", ".sf/" },
    root_content = '{ "packageDirectories": [{ "path": "force-app", "default": true }] }\n',
    chdir = true,
    -- Node server; typescript-tools/null-ls attach to .js instantly, so give
    -- the slower LWC server more than the default 2s grace to join them.
    grace_period_ms = 15000,
  },
  ["terraform-ls"] = {
    filetype = "terraform",
    filename = "main.tf",
    content = 'resource "null_resource" "test" {}\n',
  },
  ["visualforce-language-server"] = {
    filetype = "visualforce",
    filename = "pages/myPage.page",
    content = "<apex:page controller=\"MyController\">\n  <apex:form>\n    <apex:inputText value=\"{!myField}\"/>\n  </apex:form>\n</apex:page>\n",
    root_markers = { "sfdx-project.json", "force-app/" },
    root_content = '{ "packageDirectories": [{ "path": "force-app", "default": true }] }\n',
  },
  ["typescript-tools"] = {
    filetype = "typescript",
    filename = "test.ts",
    content = "const x: number = 1;\n",
  },
}

-- Name aliases: map from enable() name to actual config name when they differ.
-- Currently empty — every enabled server matches its lsp/<name>.lua config
-- name since the underscore -> hyphen consolidation.
local name_aliases = {}

local results = {}
local missing_installs = {}
local default_timeout_ms = 40000
local timeout_ms = default_timeout_ms

local function quiet_wait(ms)
  -- Headless Neovim 0.12 can surface non-fatal LSP init/shutdown assertions while
  -- we're only using vim.wait() as a brief sleep between polling steps.
  pcall(vim.wait, ms, function() return false end, ms)
end

-- Collect enabled LSP names
local enabled_lsps = {}
for name, _ in pairs(vim.lsp._enabled_configs or {}) do
  table.insert(enabled_lsps, name)
end

if #enabled_lsps == 0 then
  print("No LSPs enabled")
  return
end

table.sort(enabled_lsps)

for _, lsp_name in ipairs(enabled_lsps) do
  local config_name = name_aliases[lsp_name] or lsp_name
  local test = lsp_tests[lsp_name] or lsp_tests[config_name]
  local timeout_ms = default_timeout_ms

  if not test then
    table.insert(results, { name = lsp_name, status = "SKIP", reason = "no test mapping" })
    goto continue
  end

  -- Check binary availability
  local config = vim.lsp.config[config_name] or vim.lsp.config[lsp_name] or {}
  local cmd = config.cmd
  local binary_name = nil
  local binary_available = false

  if type(cmd) == "table" then
    binary_name = cmd[1]
    binary_available = binary_name and vim.fn.executable(binary_name) == 1
  elseif type(cmd) == "function" then
    binary_available = true
    binary_name = "(function)"
  end

  if not binary_available then
    table.insert(results, {
      name = lsp_name,
      status = "WARN",
      reason = binary_name and ("not installed: " .. binary_name) or "no cmd",
    })
    -- Collect install hint
    if binary_name then
      local hint = install_hints[binary_name] or install_hints[lsp_name]
      if hint then
        table.insert(missing_installs, { lsp = lsp_name, binary = hint.binary, manager = hint.manager, cmd = hint.cmd })
      end
    end
    goto continue
  end

  -- Create test directory + root markers
  local lsp_test_dir = test_dir .. "/" .. lsp_name
  vim.fn.mkdir(lsp_test_dir, "p")
  for _, marker in ipairs(test.root_markers or {}) do
    if marker:match("/$") then
      vim.fn.mkdir(lsp_test_dir .. "/" .. marker, "p")
    else
      local mf = io.open(lsp_test_dir .. "/" .. marker, "w")
      if mf then
        mf:write(test.root_content or "")
        mf:close()
      end
    end
  end

  -- Write test file (filename may contain subdirectories, e.g. lwc/x/x.js)
  local test_file = lsp_test_dir .. "/" .. test.filename
  vim.fn.mkdir(vim.fn.fnamemodify(test_file, ":h"), "p")
  local f = io.open(test_file, "w")
  if f then
    f:write(test.content)
    f:close()
  end

  -- Open file (some servers — e.g. the lwc wrapper — inspect the spawn cwd,
  -- so tests can opt into running with cwd = the test root)
  local orig_cwd = nil
  if test.chdir then
    orig_cwd = vim.fn.getcwd()
    vim.cmd("cd " .. vim.fn.fnameescape(lsp_test_dir))
  end
  vim.cmd("edit " .. vim.fn.fnameescape(test_file))
  vim.bo.filetype = test.filetype

  -- Wait for the expected LSP client to attach
  local client_names = {}
  local first_attach_time = nil
  local found_expected = false
  local start_time = vim.loop.now()

  while true do
    local clients = vim.lsp.get_clients({ bufnr = vim.api.nvim_get_current_buf() })

    if #clients > 0 then
      client_names = {}
      for _, c in ipairs(clients) do
        table.insert(client_names, c.name)
        if c.name == lsp_name or c.name == config_name then
          found_expected = true
        end
      end

      if first_attach_time == nil then
        first_attach_time = vim.loop.now()
      end

      if found_expected then
        break
      end

      if vim.loop.now() - first_attach_time > (test.grace_period_ms or 2000) then
        break
      end
    end

    if vim.loop.now() - start_time > timeout_ms then
      break
    end

    quiet_wait(100)
  end

  if found_expected then
    table.insert(results, {
      name = lsp_name,
      status = "OK",
      clients = client_names,
    })
  elseif #client_names > 0 then
    table.insert(results, {
      name = lsp_name,
      status = "WARN",
      reason = "attached clients: " .. table.concat(client_names, ", ") .. " (expected " .. lsp_name .. ")",
    })
  else
    table.insert(results, {
      name = lsp_name,
      status = "WARN",
      reason = "no LSP attached after " .. (timeout_ms / 1000) .. "s",
    })
  end

  -- Close buffer cleanly
  vim.cmd("bdelete!")
  if orig_cwd then
    vim.cmd("cd " .. vim.fn.fnameescape(orig_cwd))
  end
  quiet_wait(50)

  ::continue::
end

-- Print results
print("\n==> Neovim LSP Validation")
local ok_count, warn_count, skip_count = 0, 0, 0

for _, r in ipairs(results) do
  if r.status == "OK" then
    ok_count = ok_count + 1
    print(string.format("  ✓ %-25s %s", r.name, table.concat(r.clients or {}, ", ")))
  elseif r.status == "WARN" then
    warn_count = warn_count + 1
    print(string.format("  ⚠ %-25s %s", r.name, r.reason))
  else
    skip_count = skip_count + 1
    print(string.format("  ⊘ %-25s %s", r.name, r.reason))
  end
end

local summary_glyph = "✓"
if warn_count > 0 then summary_glyph = "⚠" end
if skip_count > 0 and ok_count == 0 then summary_glyph = "⊘" end
print(string.format("\n  %s %d LSPs OK, %d warnings, %d skipped",
  summary_glyph, ok_count, warn_count, skip_count))

-- Print install hints for missing binaries
if #missing_installs > 0 then
  print("\n  ⚠ Missing LSP binaries — install with:")
  for _, m in ipairs(missing_installs) do
    print(string.format("    %s: %s", m.lsp, m.cmd))
  end
end

-- ── nvim-lint linter validation ──────────────────────────────────────────────
-- Run sf code-analyzer synchronously (blocking os.execute is fine in headless)
-- rather than going through the async nvim-lint job system, which doesn't
-- complete reliably in a headless session.
print("\n==> Linter Validation Results")

local lint_ok, lint = pcall(require, "lint")
if not lint_ok then
  print("  ⊘ nvim-lint                 not loaded")
else
  local linter_name = "code_analyzer_apex"

  if not lint.linters[linter_name] then
    print(string.format("  ⊘ %-25s linter not registered", linter_name))
  elseif vim.fn.executable("sf") == 0 then
    print(string.format("  ⚠ %-25s sf CLI not found in PATH", linter_name))
  else
    -- Reuse the same file content as the apex-language-server test.
    local apex_test = lsp_tests["apex-language-server"]
    local lint_dir = test_dir .. "/lint-apex"
    vim.fn.mkdir(lint_dir, "p")
    local lint_file = lint_dir .. "/" .. apex_test.filename
    local lf = io.open(lint_file, "w")
    if lf then
      lf:write(apex_test.content)
      lf:close()
    end

    local tmpfile = vim.fn.tempname() .. ".json"
    local lint_start = vim.loop.now()

    os.execute(string.format(
      "sf code-analyzer run --target %s --workspace %s --output-file %s 2>/dev/null",
      vim.fn.shellescape(lint_file),
      vim.fn.shellescape(lint_dir),
      vim.fn.shellescape(tmpfile)
    ))

    local elapsed = math.floor((vim.loop.now() - lint_start) / 1000)
    local violation_count = 0
    local rf = io.open(tmpfile, "r")
    if rf then
      local content = rf:read("*all")
      rf:close()
      os.remove(tmpfile)
      local ok, data = pcall(vim.json.decode, content)
      if ok and type(data) == "table" then
        violation_count = #(data.violations or {})
      end
    end

    if violation_count > 0 then
      print(string.format("  ✓ %-25s %d violation(s) in %ds", linter_name, violation_count, elapsed))
    else
      print(string.format("  ⚠ %-25s ran but found no violations in %ds", linter_name, elapsed))
    end
  end
end
