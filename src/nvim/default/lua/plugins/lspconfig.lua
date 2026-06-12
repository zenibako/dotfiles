-- nvim-lspconfig is loaded purely as a data library: it ships `lsp/<name>.lua`
-- files for many language servers (e.g. ts_ls, cuelang) which Neovim 0.11+'s
-- native `vim.lsp.enable()` consumes from the runtimepath. We don't call any
-- legacy `require("lspconfig").<server>.setup()` API.
--
-- LSP *binaries* are installed via Homebrew (see Brewfile), not Mason.
vim.pack.add({
  "https://github.com/neovim/nvim-lspconfig",
})
