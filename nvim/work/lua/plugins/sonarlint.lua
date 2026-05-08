-- Optional SonarLint integration (SonarQube rules in real-time).
-- Auto-detects the SonarLint VS Code extension server JAR, similar to visualforce_ls.
local sonarlint_jar = vim.fn.glob(vim.fn.expand("~/.vscode/extensions/sonarsource.sonarlint-vscode-*/server/sonarlint-ls.jar"))

if sonarlint_jar ~= "" then
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
