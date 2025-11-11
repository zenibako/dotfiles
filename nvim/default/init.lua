vim.g.mapleader = " "
{{#unless lsp_salesforce_disabled}}

-- Load Salesforce filetype detection BEFORE plugins
require("config.salesforce")
{{/unless}}

require("config.formatting")
require("config.lazy")
require("config.keymaps")
require("config.lsp")

vim.opt.hlsearch = true

vim.api.nvim_create_autocmd("TermOpen", {
  group = vim.api.nvim_create_augroup("custom-term-open", { clear = true }),
  callback = function()
    vim.opt.number = false
    vim.opt.relativenumber = false
  end,
})

vim.cmd("{{vim_set_num_relnum}}")
