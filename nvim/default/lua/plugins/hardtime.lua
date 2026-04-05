vim.pack.add("https://github.com/MunifTanjim/nui.nvim")
vim.pack.add("https://github.com/m4xshen/hardtime.nvim")
require("hardtime").setup({
  disable_mouse = false,
  disabled_filetypes = { fujjitive = true, fujjitiveblame = true },
})
