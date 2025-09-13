return {
  "folke/which-key.nvim",
  dependencies = {
    { "echasnovski/mini.nvim", version = false },
    "nvim-tree/nvim-web-devicons",
  },
  event = "VeryLazy",
  init = function()
    vim.o.timeout = true
    vim.o.timeoutlen = 300
  end,
  opts = {
    notify = false
  },
}
