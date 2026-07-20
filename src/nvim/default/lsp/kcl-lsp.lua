---@type vim.lsp.Config
return {
	cmd = { "kcl-language-server" },
	root_markers = { "kcl.mod", ".git" },
	filetypes = { "kcl" },
}
