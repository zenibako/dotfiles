vim.g.mapleader = " "

require("config.formatting")
require("config.lazy")
require("config.keymaps")
-- require("config.rocks")
require("config.salesforce")

vim.opt.hlsearch = true

vim.api.nvim_create_autocmd("TermOpen", {
	group = vim.api.nvim_create_augroup("custom-term-open", { clear = true }),
	callback = function()
		vim.opt.number = false
		vim.opt.relativenumber = false
	end,
})

vim.lsp.enable({
	"apex-language-server",
  "astro",
	"gitlab_ci_ls",
	"gopls",
	"html",
	"jsonls",
	"lua_ls",
	"lwc_ls",
	"terraformls",
	-- "ts_ls",
	"visualforce_ls",
	"yamlls",
})

vim.cmd("set number relativenumber")
