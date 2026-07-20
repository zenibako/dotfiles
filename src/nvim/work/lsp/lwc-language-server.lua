local wrapper = vim.fn.expand("~/.config/opencode/script/lwc-lsp-wrapper.sh")

return {
	cmd = { wrapper },
	filetypes = { "javascript", "html" },
	-- The server maps over workspaceFolders during initialize and crashes when
	-- none are sent, so require a resolved SFDX workspace before spawning.
	root_markers = { "sfdx-project.json", ".sf" },
	workspace_required = true,
}
