-- Recognize Salesforce extensions so proper LSPs activate
vim.filetype.add({
	extension = { 
		cls = "apex", 
		trigger = "apex", 
		component = "visualforce", 
		apex = "apex",
		page = "visualforce",
	},
})

-- Override Neovim's built-in .page -> html detection
-- This must run after filetype detection, so we use BufRead autocmd
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
	pattern = "*.page",
	callback = function()
		vim.bo.filetype = "visualforce"
	end,
})

-- Detach HTML LSP from visualforce files (runs after LSP attach)
vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(args)
		local bufnr = args.buf
		local client = vim.lsp.get_client_by_id(args.data.client_id)
		
		-- If HTML LSP attached to a visualforce file, detach it
		if client and client.name == "html" and vim.bo[bufnr].filetype == "visualforce" then
			vim.lsp.buf_detach_client(bufnr, args.data.client_id)
		end
	end,
})
