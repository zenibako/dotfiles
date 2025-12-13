vim.g.mapleader = " "

require("config.formatting")
require("config.lazy")
require("config.keymaps")

-- Conditionally load LSP config if it exists (provided by work/personal profiles)
pcall(require, "config.lsp")

vim.opt.hlsearch = true

vim.api.nvim_create_autocmd("TermOpen", {
  group = vim.api.nvim_create_augroup("custom-term-open", { clear = true }),
  callback = function()
    vim.opt.number = false
    vim.opt.relativenumber = false
  end,
})

vim.cmd("{{vim_set_num_relnum}}")
