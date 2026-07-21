---@type vim.lsp.Config
return {
	cmd = { "kotlin-langserver" },
	root_markers = { "settings.json", ".git", "build.gradle.kts", "build.gradle" },
	filetypes = { "kotlin", "scala", "kcl" },
}
