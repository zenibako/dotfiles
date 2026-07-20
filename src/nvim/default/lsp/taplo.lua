---@type vim.lsp.Config
return {
	cmd = { "taplo", "lsp" },
	filetypes = { "toml" },
	root_markers = { ".taplo.toml", ".git", "taplo.toml" },
}
