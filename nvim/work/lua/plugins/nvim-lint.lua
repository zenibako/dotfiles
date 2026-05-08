vim.pack.add({
	"https://github.com/mfussenegger/nvim-lint",
})

local lint = require("lint")

-- Shared PMD parser for emacs-style output: file:line: message
local function parse_pmd_output(output, severity)
	local diagnostics = {}
	for line in output:gmatch("[^\r\n]+") do
		local file, lnum, message = line:match("([^:]+):(%d+): (.+)")
		if file and lnum and message then
			table.insert(diagnostics, {
				lnum = tonumber(lnum) - 1,
				col = 0,
				message = message,
				severity = severity,
				source = "pmd",
			})
		end
	end
	return diagnostics
end

-- Factory: build a PMD Apex linter with the given rulesets and severity.
local function make_pmd_linter(name, rulesets, severity)
	lint.linters[name] = {
		cmd = "pmd",
		stdin = false,
		args = {
			"check",
			"--format",
			"emacs",
			"--rulesets",
			rulesets,
			"--dir",
		},
		stream = "stdout",
		ignore_exitcode = true,
		parser = function(output, bufnr, linter_cwd)
			return parse_pmd_output(output, severity)
		end,
	}
end

-- Core: critical rules shown as WARN (virtual_lines on current line).
make_pmd_linter(
	"pmd_apex_core",
	"category/apex/errorprone.xml,category/apex/performance.xml,category/apex/bestpractices.xml,category/apex/security.xml",
	vim.diagnostic.severity.WARN
)

-- Style: non-critical rules shown as HINT (subtle inline dots).
make_pmd_linter(
	"pmd_apex_style",
	"category/apex/codestyle.xml,category/apex/design.xml,category/apex/documentation.xml",
	vim.diagnostic.severity.HINT
)

lint.linters_by_ft = {
	apex = { "pmd_apex_core", "pmd_apex_style" },
}

-- Warn once per session if PMD is not installed when opening an Apex file.
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

-- Trigger linting on save, read, and filetype detection.
vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "FileType" }, {
	callback = function(args)
		local ft = vim.bo[args.buf].filetype
		if lint.linters_by_ft[ft] then
			lint.try_lint()
		end
	end,
})
