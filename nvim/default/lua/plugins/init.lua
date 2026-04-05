-- Core dependencies
vim.pack.add("https://github.com/nvim-lua/plenary.nvim")
vim.pack.add("https://github.com/nvim-tree/nvim-web-devicons")

-- Simple plugins
vim.pack.add("https://github.com/eandrju/cellular-automaton.nvim")
vim.pack.add("https://github.com/rafikdraoui/jj-diffconflicts")

-- Copilot
vim.pack.add("https://github.com/zbirenbaum/copilot.lua")
require("copilot").setup({
  suggestion = { enabled = false },
  panel = { enabled = false },
  filetypes = {
    jjdescription = false,
    markdown = false,
    help = false,
  },
})

-- Blink completion
vim.pack.add("https://github.com/rafamadriz/friendly-snippets")
vim.pack.add("https://github.com/fang2hou/blink-copilot")
vim.pack.add("https://github.com/saghen/blink.cmp")
require("blink.cmp").setup({
  keymap = {
    preset = "enter",
    ["<S-Tab>"] = { "select_prev", "fallback" },
    ["<Tab>"] = { "select_next", "fallback" },
  },
  appearance = {
    nerd_font_variant = "mono",
  },
  completion = { documentation = { auto_show = true } },
  sources = {
    default = { "lsp", "path", "snippets", "buffer", "copilot" },
    providers = {
      copilot = {
        name = "copilot",
        module = "blink-copilot",
        score_offset = 100,
        async = true,
      },
    },
  },
  fuzzy = { implementation = "prefer_rust_with_warning" },
})

-- LazyJJ
vim.pack.add("https://github.com/zenibako/lazyjj.nvim")
require("lazyjj").setup({})
