local wrapper = vim.fn.expand("~/.config/opencode/script/lwc-lsp-wrapper.sh")

return {
	cmd = { wrapper },
	filetypes = { "javascript", "html" },
}
