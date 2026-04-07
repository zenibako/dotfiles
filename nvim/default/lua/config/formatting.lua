vim.cmd("set tabstop=2")
vim.cmd("set shiftwidth=2")
vim.cmd("set expandtab")

vim.keymap.set("n", "<leader>f", vim.lsp.buf.format)

-- Native insert-mode autocompletion (Neovim 0.12)
vim.o.autocomplete = true
vim.o.completeopt = "menu,menuone,noinsert,popup,nearest"

vim.keymap.set("i", "<Tab>", function()
  return vim.fn.pumvisible() == 1 and "<C-n>" or "<Tab>"
end, { expr = true })
vim.keymap.set("i", "<S-Tab>", function()
  return vim.fn.pumvisible() == 1 and "<C-p>" or "<S-Tab>"
end, { expr = true })
vim.o.pumborder = "rounded"

vim.diagnostic.config({
  virtual_lines = { current_line = true },
})
