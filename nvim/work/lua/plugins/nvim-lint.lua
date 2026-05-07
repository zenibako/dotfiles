vim.pack.add({
	"https://github.com/mfussenegger/nvim-lint",
})

local lint = require("lint")

-- Custom PMD linter definition for Apex.
-- Requires `pmd` to be installed and available in $PATH (e.g. `brew install pmd`).
lint.linters.pmd_apex = {
	cmd = "pmd",
	stdin = false,
	args = function()
		return {
			"check",
			"--format",
			"emacs",
			"--rulesets",
			"category/apex/errorprone.xml,category/apex/performance.xml,category/apex/security.xml,category/apex/bestpractices.xml",
			"--dir",
			vim.fn.expand("%:p"),
		}
	end,
	stream = "stdout",
	ignore_exitcode = true,
	parser = function(output, bufnr, linter_cwd)
		local diagnostics = {}
		-- emacs format: file:line: message
		local pattern = "([^:]+):(%d+): (.+)"
		for line in output:gmatch("[^\r\n]+") do
			local file, lnum, message = line:match(pattern)
			if file and lnum and message then
				table.insert(diagnostics, {
					lnum = tonumber(lnum) - 1,
					col = 0,
					message = message,
					severity = vim.diagnostic.severity.WARN,
					source = "pmd",
				})
			end
		end
		return diagnostics
	end,
}

lint.linters_by_ft = {
	apex = { "pmd_apex" },
}

-- Trigger linting after saving or reading a buffer
vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost" }, {
	callback = function()
		lint.try_lint()
	end,
})
