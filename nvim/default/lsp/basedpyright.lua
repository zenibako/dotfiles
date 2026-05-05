---@type vim.lsp.Config
return {
	cmd = { "basedpyright-langserver", "--stdio" },
	root_markers = {
		"pyproject.toml",
		"setup.py",
		"setup.cfg",
		"requirements.txt",
		"Pipfile",
		".git",
	},
	filetypes = { "python" },
}
