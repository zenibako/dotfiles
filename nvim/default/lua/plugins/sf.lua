return {
  "xixiaofinland/sf.nvim",

  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "ibhagwan/fzf-lua", -- no need if you don't use listing metadata feature
    "stevearc/overseer.nvim",
  },

  config = function()
    require("sf").setup({
      enable_hotkeys = true,
      terminal = "overseer",
    })
  end,
}
