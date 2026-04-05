vim.pack.add({ { src = "https://github.com/ThePrimeagen/harpoon", version = "harpoon2" } })

local harpoon = require("harpoon")
harpoon:setup()

vim.keymap.set("n", "<leader>a", function() harpoon:list():add() end, { desc = "Harpoon: Add file" })
vim.keymap.set("n", "<C-e>", function() harpoon.ui:toggle_quick_menu(harpoon:list()) end, { desc = "Harpoon: Quick menu" })

vim.keymap.set("n", "<C-h>", function() harpoon:list():select(1) end, { desc = "Harpoon: Jump to 1" })
vim.keymap.set("n", "<C-t>", function() harpoon:list():select(2) end, { desc = "Harpoon: Jump to 2" })
vim.keymap.set("n", "<C-n>", function() harpoon:list():select(3) end, { desc = "Harpoon: Jump to 3" })
vim.keymap.set("n", "<C-s>", function() harpoon:list():select(4) end, { desc = "Harpoon: Jump to 4" })

vim.keymap.set("n", "<C-S-P>", function() harpoon:list():prev() end, { desc = "Harpoon: Jump to Previous" })
vim.keymap.set("n", "<C-S-N>", function() harpoon:list():next() end, { desc = "Harpoon: Jump to Next" })
