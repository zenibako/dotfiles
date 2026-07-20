---@type vim.lsp.Config
return {
	cmd = { "starlark-rust" },
	filetypes = { "starlark" },
	root_markers = { "BUILD", ".git" },
}
