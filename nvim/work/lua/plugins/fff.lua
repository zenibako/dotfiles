vim.pack.add({"https://github.com/dmtrKovalenko/fff.nvim"})
require("fff").setup({})

vim.keymap.set("n", "ff", function()
  require("fff").find_files()
end, { desc = "Open file picker" })
