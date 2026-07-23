-- Optional SonarLint integration (SonarQube rules in real-time).
-- Uses the VSIX-unpacked server from scripts/lsp_vsix_sync.sh; the analyzers/
-- directory sits beside server/ exactly as in the extension layout.
local sonarlint_jar = vim.fn.expand("~/.local/share/lsp-servers/sonarlint-vscode/server/sonarlint-ls.jar")

if vim.fn.filereadable(sonarlint_jar) == 1 then
	vim.pack.add({
		"https://gitlab.com/schrieveslaach/sonarlint.nvim",
	})

	require("sonarlint").setup({
		server = {
			cmd = {
				"java",
				"-jar",
				sonarlint_jar,
				"-stdio",
			},
		},
		filetypes = {
			"apex",
			"java",
			"javascript",
			"typescript",
			"python",
		},
	})
end
