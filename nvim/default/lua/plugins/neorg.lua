return {
  "nvim-neorg/neorg",
  lazy = false, -- Disable lazy loading as some `lazy.nvim` distributions set `lazy = true` by default
  version = "*", -- Pin Neorg to the latest stable release
  build = ":Neorg sync-parsers",
  opts = {
    load = {
      ["core.defaults"] = {}, -- Loads default behaviour
      ["core.concealer"] = {}, -- Adds pretty icons to your documents
      ["core.dirman"] = {   -- Manages Neorg workspaces
        config = {
          workspaces = {
            notes = "~/notes",
          },
          default_workspace = "notes",
        },
      },
      -- ["core.integrations.telescope"] = {},
    },
  },
  dependencies = {
    {
      "nvim-lua/plenary.nvim",
      "nvim-neorg/lua-utils.nvim",
      "pysan3/pathlib.nvim",
      "nvim-neotest/nvim-nio",
      "MunifTanjim/nui.nvim",
      -- "nvim-neorg/neorg-telescope",
    },
    {
      -- YOU ALMOST CERTAINLY WANT A MORE ROBUST nvim-treesitter SETUP
      -- see https://github.com/nvim-treesitter/nvim-treesitter
      "nvim-treesitter/nvim-treesitter",
      opts = {
        auto_install = true,
        highlight = {
          enable = true,
          additional_vim_regex_highlighting = false,
        },
      },
      config = function(_, opts)
        require("nvim-treesitter.configs").setup(opts)
      end,
    },
  },
}
