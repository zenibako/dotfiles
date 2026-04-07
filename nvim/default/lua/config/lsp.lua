-- Declarative LSP setup (Neovim 0.11+).
-- Server configs are auto-loaded from `lsp/<name>.lua` directories on the runtimepath.
vim.lsp.enable({
  "gopls",
  "html",
  "jsonls",
  "lua_ls",
  "yamlls",
})
