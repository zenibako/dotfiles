---@type vim.lsp.Config
return {
  cmd = { "lwc-language-server", "--stdio" },
  filetypes = { "javascript", "html" },
  root_markers = { "sfdx-project.json" },
  init_options = {
    embeddedLanguages = {
      javascript = true,
    },
  },
}
