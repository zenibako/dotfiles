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

-- Highlight unused variables/functions with a subtle strikethrough.
vim.diagnostic.config({
	underline = { severity = vim.diagnostic.severity.HINT },
	virtual_text = {
		prefix = "●",
		spacing = 2,
		format = function()
			return ""
		end,
	},
	virtual_lines = true,
	update_in_insert = false,
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
  "pkl_lsp",
{{#if opencode_profile_work}}
  "lwc_ls",
  "starlark_rust",
  "terraformls",
  "visualforce_ls",
{{/if}}
  "kcl_lsp",
  "yamlls",
  "taplo",
{{#if opencode_profile_personal}}
  "cue",
  "starlark_rust",
  "sourcekit",
  "jinja-lsp",
{{/if}}
{{#if opencode_profile_work}}
  "cue",
{{/if}}
})
