vim.pack.add({
	"https://github.com/mfussenegger/nvim-lint",
})

local lint = require("lint")

-- Core PMD linter for Apex (critical rules: errors, performance, security, best practices)
-- Shown as WARN so they appear in virtual_lines on the current line.
lint.linters.pmd_apex_core = {
	cmd = "pmd",
	stdin = false,
	args = {
		"check",
		"--format",
		"emacs",
		"--rulesets",
		"category/apex/errorprone.xml,category/apex/performance.xml,category/apex/bestpractices.xml,category/apex/security.xml",
		"--dir",
	},
	stream = "stdout",
	ignore_exitcode = true,
	parser = function(output, bufnr, linter_cwd)
		local diagnostics = {}
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

-- Style PMD linter for Apex (code style, design, documentation)
-- Shown as HINT so they appear less prominently.
lint.linters.pmd_apex_style = {
	cmd = "pmd",
	stdin = false,
	args = {
		"check",
		"--format",
		"emacs",
		"--rulesets",
		"category/apex/codestyle.xml,category/apex/design.xml,category/apex/documentation.xml",
		"--dir",
	},
	stream = "stdout",
	ignore_exitcode = true,
	parser = function(output, bufnr, linter_cwd)
		local diagnostics = {}
		local pattern = "([^:]+):(%d+): (.+)"
		for line in output:gmatch("[^\r\n]+") do
			local file, lnum, message = line:match(pattern)
			if file and lnum and message then
				table.insert(diagnostics, {
					lnum = tonumber(lnum) - 1,
					col = 0,
					message = message,
					severity = vim.diagnostic.severity.HINT,
					source = "pmd",
				})
			end
		end
		return diagnostics
	end,
}

lint.linters_by_ft = {
	apex = { "pmd_apex_core", "pmd_apex_style" },
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

-- Trigger linting on save, read, and filetype detection
vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "FileType" }, {
	callback = function(args)
		local ft = vim.bo[args.buf].filetype
		if lint.linters_by_ft[ft] then
			lint.try_lint()
		end
	end,
})
