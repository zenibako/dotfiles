#!/usr/bin/env lua
-- validate_lsp.lua: Validate Neovim LSP attachments after deploy
-- Usage: nvim --headless -c "luafile validate_lsp.lua" -c "qa!"
--
-- This checks that enabled LSPs have their binaries available and can attach
-- to test buffers. Warnings are expected for missing servers — exits 0.

local test_dir = vim.fn.tempname() .. "-nvim-lsp-test"
vim.fn.mkdir(test_dir, "p")

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
  ["lua_ls"] = {
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
  ts_ls = {
    filetype = "typescript",
    filename = "test.ts",
    content = "const x: number = 1;\n",
  },
  cue = {
    filetype = "cue",
    filename = "test.cue",
    content = "package test\n\n// test comment\n",
    root_markers = { "cue.mod" },
    root_content = "",
  },
  sourcekit = {
    filetype = "swift",
    filename = "test.swift",
    content = 'import Foundation\nprint("hello")\n',
  },
  ["jinja-lsp"] = {
    filetype = "jinja",
    filename = "test.jinja",
    content = "{{ variable }}\n",
  },
  ["apex-language-server"] = {
    filetype = "apex",
    filename = "Test.cls",
    content = "public class Test {}\n",
  },
  gitlab_ci_ls = {
    filetype = "yaml",
    filename = ".gitlab-ci.yml",
    content = "stages:\n  - build\n",
  },
  lwc_ls = {
    filetype = "javascript",
    filename = "test.js",
    content = "export default class Test extends LightningElement {}\n",
    root_markers = { "sfdx-project.json" },
    root_content = '{ "packageDirectories": [{ "path": "force-app" }] }\n',
    grace_period_ms = 30000,
  },
  terraformls = {
    filetype = "terraform",
    filename = "main.tf",
    content = 'resource "null_resource" "test" {}\n',
  },
  visualforce_ls = {
    filetype = "visualforce",
    filename = "test.page",
    content = "<apex:page></apex:page>\n",
    root_markers = { "sfdx-project.json" },
    root_content = '{ "packageDirectories": [{ "path": "force-app" }] }\n',
    grace_period_ms = 30000,
  },
  ["typescript-tools"] = {
    filetype = "typescript",
    filename = "test.ts",
    content = "const x: number = 1;\n",
  },
}

-- Name aliases: map from enable() name to actual config name when they differ.
-- Some LSP configs ship under a different name than what's passed to enable().
local name_aliases = {
  cue = "cue",
}

local results = {}
local default_timeout_ms = 40000  -- 40 seconds per LSP (Salesforce servers can take 15-20s)
local timeout_ms = default_timeout_ms

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

  -- Check binary availability (cmd may be a table or a function)
  local config = vim.lsp.config[config_name] or vim.lsp.config[lsp_name] or {}
  local cmd = config.cmd
  local binary_name = nil
  local binary_available = false

  if type(cmd) == "table" then
    binary_name = cmd[1]
    binary_available = binary_name and vim.fn.executable(binary_name) == 1
  elseif type(cmd) == "function" then
    -- For wrapper plugins (e.g. typescript-tools.nvim), skip binary check
    -- and rely on the attachment test. Assume available and let it timeout
    -- if the underlying binary (tsserver) is missing.
    binary_available = true
    binary_name = "(function)"
  end

  if not binary_available then
    table.insert(results, {
      name = lsp_name,
      status = "WARN",
      reason = binary_name and ("not installed: " .. binary_name) or "no cmd",
    })
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

  -- Write test file
  local test_file = lsp_test_dir .. "/" .. test.filename
  local f = io.open(test_file, "w")
  if f then
    f:write(test.content)
    f:close()
  end

  -- Open file
  vim.cmd("edit " .. vim.fn.fnameescape(test_file))
  vim.bo.filetype = test.filetype

  -- Wait for the expected LSP client to attach (with a grace period for slow servers)
  local client_names = {}
  local first_attach_time = nil
  local found_expected = false
  local start_time = vim.loop.now()

  while true do
    local clients = vim.lsp.get_clients({ bufnr = vim.api.nvim_get_current_buf() })

    if #clients > 0 then
      -- Record all attached clients
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

      -- If expected client found, success
      if found_expected then
        break
      end

      -- Give a grace period after first client attaches for other clients to arrive
      if vim.loop.now() - first_attach_time > (test.grace_period_ms or 2000) then
        break  -- Grace period exceeded
      end
    end

    -- Global timeout
    if vim.loop.now() - start_time > timeout_ms then
      break
    end

    vim.wait(100, function() return false end, 100)
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
  -- Small delay to let plugins clean up (typescript-tools buffers etc.)
  vim.wait(50, function() return false end, 50)

  ::continue::
end

-- Print results
print("\n== LSP Validation Results ==")
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

print(string.format("\n%d OK, %d warnings, %d skipped", ok_count, warn_count, skip_count))
