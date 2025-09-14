---@type vim.lsp.Config
return {
  cmd = {
    vim.fn.expand("$HOME/.local/share/nvim/mason/bin/visualforce-language-server"),
    "--stdio",
  },
  filetypes = { "visualforce", "page", "component" },
  root_markers = { "sfdx-project.json" },
  init_options = {
    embeddedLanguages = {
      css = true,
      javascript = true,
    },
    provideFormatter = true,
  },
}
