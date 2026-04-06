vim.pack.add({"https://github.com/ThePrimeagen/99"})

local _99 = require("99")

local cwd = vim.uv.cwd() or vim.fn.getcwd()
local basename = vim.fs.basename(cwd)
_99.setup({
  logger = {
    level = _99.DEBUG,
    path = vim.fs.joinpath(vim.fn.stdpath("log"), basename .. ".99.debug"),
    print_on_error = true,
  },

  completion = {
    custom_rules = {
      "scratch/custom_rules/",
    },
  },

  md_files = {
    "AGENTS.md",
  },
})

vim.keymap.set("n", "<leader>9f", function()
  _99.fill_in_function()
end)

vim.keymap.set("v", "<leader>9v", function()
  _99.visual()
end)

vim.keymap.set("v", "<leader>9s", function()
  _99.stop_all_requests()
end)

vim.keymap.set("n", "<leader>9fd", function()
  _99.fill_in_function()
end)
