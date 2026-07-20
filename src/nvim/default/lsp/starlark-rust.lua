---@type vim.lsp.Config
return {
	-- The starlark-rust brew formula installs its binary as `starlark`.
	cmd = { "starlark", "--lsp" },
	filetypes = { "starlark" },
	root_markers = { "BUILD", ".git" },
}
