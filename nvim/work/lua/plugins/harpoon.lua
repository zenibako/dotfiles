return {
  "ThePrimeagen/harpoon",
  branch = "harpoon2",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "folke/which-key.nvim",
  },
  config = function()
    local harpoon = require("harpoon")
    harpoon:setup()

    local wk = require("which-key")
    wk.add({
      { "<leader>a", function() harpoon:list():add() end,                         desc = "Harpoon: Add file" },
      { "<C-e>",     function() harpoon.ui:toggle_quick_menu(harpoon:list()) end, desc = "Harpoon: Quick menu" },

      { "<C-h>",     function() harpoon:list():select(1) end,                     desc = "Harpoon: Jump to 1" },
      { "<C-t>",     function() harpoon:list():select(2) end,                     desc = "Harpoon: Jump to 2" },
      { "<C-n>",     function() harpoon:list():select(3) end,                     desc = "Harpoon: Jump to 3" },
      { "<C-s>",     function() harpoon:list():select(4) end,                     desc = "Harpoon: Jump to 4" },

      -- Toggle previous & next buffers stored within Harpoon list
      { "<C-S-P>",   function() harpoon:list():prev() end,                        desc = "Harpoon: Jump to Previous" },
      { "<C-S-N>",   function() harpoon:list():next() end,                        desc = "Harpoon: Jump to Next" },
    })
  end
}
