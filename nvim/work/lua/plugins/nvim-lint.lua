vim.pack.add({
	"https://github.com/mfussenegger/nvim-lint",
})

local lint = require("lint")

-- Custom PMD linter definition for Apex.
-- Requires `pmd` to be installed and available in $PATH (e.g. `brew install pmd`).
-- Note: args must be a TABLE (not a function) for compatibility with the
-- nvim-lint version distributed by vim.pack.add. The filename is appended
-- automatically by nvim-lint after the `--dir` flag.
lint.linters.pmd_apex = {
	cmd = "pmd",
	stdin = false,
	args = {
		"check",
		"--format",
		"emacs",
		"--rulesets",
		"category/apex/errorprone.xml,category/apex/performance.xml,category/apex/security.xml,category/apex/bestpractices.xml",
		"--dir",
	},
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

-- Warn once per session if PMD is not installed when opening an Apex file
local pmd_warned = false
vim.api.nvim_create_autocmd("FileType", {
	pattern = "apex",
	callback = function()
		if not pmd_warned and vim.fn.executable("pmd") == 0 then
			pmd_warned = true
			vim.notify(
				"PMD not found in PATH. Apex diagnostics will not work.\n"
					.. "Install PMD, e.g. `brew install pmd`.",
				vim.log.levels.WARN,
				{ title = "nvim-lint (PMD)" }
			)
		end
	end,
})

-- Trigger linting after saving or reading a buffer
vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost" }, {
	callback = function()
		lint.try_lint()
	end,
})
