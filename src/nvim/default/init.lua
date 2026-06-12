vim.g.mapleader = " "

require("config.formatting")
require("config.neovide")
require("config.pack")
require("config.keymaps")

require("config.lsp")

vim.opt.hlsearch = true

-- Visually highlight unused variables/functions with a subtle strikethrough.
vim.api.nvim_set_hl(0, 'DiagnosticUnnecessary', { strikethrough = true, fg = '#6c7086' })

vim.api.nvim_create_autocmd("TermOpen", {
  group = vim.api.nvim_create_augroup("custom-term-open", { clear = true }),
  callback = function()
    vim.opt.number = false
    vim.opt.relativenumber = false
  end,
})

vim.cmd("{{vim_set_num_relnum}}")
