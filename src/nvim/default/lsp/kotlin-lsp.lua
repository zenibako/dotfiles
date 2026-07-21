---@type vim.lsp.Config
return {
	cmd = { "kotlin-lsp", "--stdio" },
	root_markers = { "settings.gradle", "settings.gradle.kts", "pom.xml", "build.gradle", "build.gradle.kts", ".git" },
	filetypes = { "kotlin" },
}
