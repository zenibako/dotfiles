-- Simple plugins (batched for parallel install)
vim.pack.add({
  "https://github.com/eandrju/cellular-automaton.nvim",
  "https://github.com/rafikdraoui/jj-diffconflicts",
  "https://github.com/zenibako/lazyjj.nvim",
})

require("lazyjj").setup({})
