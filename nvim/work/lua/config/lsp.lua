-- Load Salesforce filetype detection BEFORE enabling LSPs
require("config.salesforce")

local visualforce_ext = vim.fn.glob(vim.fn.expand("~/.vscode/extensions/salesforce.salesforcedx-vscode-visualforce-*/dist/visualforceServer.js"))

-- Use nvim-lspconfig's built-in server definitions, but patch Visualforce with
-- the actual server entrypoint shipped by the installed VS Code extension.
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

vim.lsp.enable({
  "apex-language-server",
  "gitlab_ci_ls",
  "gopls",
  "html",
  "jsonls",
  "lua_ls",
  "lwc_ls",
  "terraformls",
  "ts_ls",
  "visualforce_ls",
  "yamlls",
  "cuelang",
})
