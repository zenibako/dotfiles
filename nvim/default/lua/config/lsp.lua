{{#if opencode_profile_work}}
-- Load Salesforce filetype detection BEFORE enabling LSPs.
require("config.salesforce")

local visualforce_ext = vim.fn.glob(vim.fn.expand("~/.vscode/extensions/salesforce.salesforcedx-vscode-visualforce-*/dist/visualforceServer.js"))

-- Use the VS Code Visualforce server when the extension is installed locally.
if visualforce_ext ~= "" then
  vim.lsp.config("visualforce_ls", {
    cmd = { "node", visualforce_ext, "--stdio" },
    init_options = {
      embeddedLanguages = {
        css = true,
        javascript = true,
      },
      provideFormatter = true,
    },
    settings = {
      html = {
        format = {
          enable = true,
          wrapLineLength = 120,
          wrapAttributes = "auto",
          indentInnerHtml = false,
          preserveNewLines = true,
          maxPreserveNewLines = 2,
          indentHandlebars = false,
          endWithNewline = true,
          extraLiners = "head, body, /html",
          templating = false,
        },
        suggest = {
          html5 = true,
        },
        validate = {
          scripts = true,
          styles = true,
        },
        autoClosingTags = true,
        mirrorCursorOnMatchingTag = false,
      },
    },
  })
end
{{/if}}

-- Declarative LSP setup (Neovim 0.11+).
-- Server configs are auto-loaded from `lsp/<name>.lua` directories on the runtimepath.

-- Diagnostic display: full multiline on current line, compact dots elsewhere.
-- Neovim 0.12+ does not support `current_line` for virtual_text, so we use
-- a CursorMoved autocmd to toggle virtual_text off when the cursor is on a
-- line with diagnostics, letting virtual_lines render everything inline.
local ns = vim.api.nvim_create_namespace("diagnostic_toggle")

vim.diagnostic.config({
	underline = { severity = vim.diagnostic.severity.HINT },
	virtual_text = { prefix = "●", spacing = 2 },
	virtual_lines = { current_line = true },
	update_in_insert = false,
})

-- Track lines with diagnostics per buffer
local diag_lines = {}

vim.api.nvim_create_autocmd({ "DiagnosticChanged", "BufEnter" }, {
	callback = function(args)
		local bufnr = args.buf
		diag_lines[bufnr] = {}
		for _, d in ipairs(vim.diagnostic.get(bufnr)) do
			diag_lines[bufnr][d.lnum] = true
		end
	end,
})

vim.api.nvim_create_autocmd("CursorMoved", {
	callback = function()
		local bufnr = vim.api.nvim_get_current_buf()
		local lnum = vim.api.nvim_win_get_cursor(0)[1] - 1
		local has_diag = diag_lines[bufnr] and diag_lines[bufnr][lnum] or false

		if has_diag then
			-- Hide virtual_text on current line; virtual_lines takes over
			vim.diagnostic.config({ virtual_text = false })
		else
			-- Show virtual_text on lines without diagnostics
			vim.diagnostic.config({ virtual_text = { prefix = "●", spacing = 2 } })
		end
	end,
})

vim.lsp.enable({
{{#if opencode_profile_work}}
  "apex-language-server",
  "gitlab_ci_ls",
{{/if}}
  "gopls",
  "basedpyright",
  "html",
  "jsonls",
  "lua_ls",
{{#if opencode_profile_work}}
  "lwc_ls",
  "terraformls",
  "ts_ls",
  "visualforce_ls",
{{/if}}
  "yamlls",
{{#if opencode_profile_personal}}
  "ts_ls",
  "cuelang",
  "sourcekit",
  "jinja-lsp",
{{/if}}
{{#if opencode_profile_work}}
  "cuelang",
{{/if}}
})
