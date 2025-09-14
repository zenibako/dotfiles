---@type vim.lsp.Config
return {
  cmd = {
    vim.fn.expand("$HOME/.local/share/nvim/mason/bin/lwc-language-server"),
    "--stdio"
  },
  filetypes = { "javascript", "html" },
  root_markers = { "sfdx-project.json" },
  init_options = {
    embeddedLanguages = {
      javascript = true,
    },
  },
}
