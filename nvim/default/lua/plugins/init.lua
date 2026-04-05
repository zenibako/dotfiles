-- Core dependencies + simple plugins (batched for parallel install)
vim.pack.add({
  "https://github.com/nvim-lua/plenary.nvim",
  "https://github.com/nvim-tree/nvim-web-devicons",
  "https://github.com/eandrju/cellular-automaton.nvim",
  "https://github.com/rafikdraoui/jj-diffconflicts",
  "https://github.com/zenibako/lazyjj.nvim",
})

require("lazyjj").setup({})
