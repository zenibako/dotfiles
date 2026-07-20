{{#if opencode_profile_work}}
-- Load Salesforce filetype detection BEFORE enabling LSPs.
require("config.salesforce")

local visualforce_ext = vim.fn.glob(vim.fn.expand("~/.vscode/extensions/salesforce.salesforcedx-vscode-visualforce-*/dist/visualforceServer.js"))

-- Use the VS Code Visualforce server when the extension is installed locally.
if visualforce_ext ~= "" then
  vim.lsp.config("visualforce-language-server", {
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
  vim.lsp.enable("visualforce-language-server")
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

-- NOTE: no runtime directory checks here. Profile dirs (src/nvim/work,
-- src/nvim/personal) deploy INTO ~/.config/nvim (merged flat), so paths like
-- ~/.config/nvim/work/lsp never exist at runtime — and vim.fn.isdirectory()
-- doesn't expand `~` anyway. The handlebars profile gates are the guard: they
-- guarantee the corresponding lsp/<name>.lua configs were deployed.

{{#if opencode_profile_work}}
-- Work LSP servers: configs from src/nvim/work/lsp/ (visualforce is enabled
-- above, only when the VS Code extension provides its server).
vim.lsp.enable({
  "apex-language-server",
  "gitlab-ci-ls",
  "lwc-language-server",
  "terraform-ls",
})
{{/if}}

{{#if opencode_profile_personal}}
-- Personal LSP servers: configs from src/nvim/personal/lsp/
vim.lsp.enable({
  "jinja-lsp",
  "sourcekit-lsp",
})
{{/if}}

-- Default LSP servers (configs in src/nvim/default/lsp/ — always available).
vim.lsp.enable({
  "basedpyright",
  "cue",
  "gopls",
  "html",
  "jsonls",
  "kcl-lsp",
  "lua-ls",
  "pkl-lsp",
  "starlark-rust",
  "taplo",
  "yamlls",
})
