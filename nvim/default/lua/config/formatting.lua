vim.cmd("set tabstop=2")
vim.cmd("set shiftwidth=2")
vim.cmd("set expandtab")

vim.keymap.set("n", "<leader>f", vim.lsp.buf.format)

-- Native insert-mode autocompletion (Neovim 0.12)
vim.o.autocomplete = true
vim.o.completeopt = "menu,menuone,popup,nearest"
vim.o.pumborder = "rounded"

vim.diagnostic.config({
  -- -- update_in_insert = true,
  -- float = {
  --   focusable = false,
  --   style = "minimal",
  --   border = "rounded",
  --   source = "always",
  --   header = "",
  --   prefix = "",
  -- },
  virtual_lines = true
})
