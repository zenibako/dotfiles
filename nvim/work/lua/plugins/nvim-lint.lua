vim.pack.add({
	"https://github.com/mfussenegger/nvim-lint",
})

local lint = require("lint")

-- Resolve rulesets: prefer project-local apexRuleSets.xml.
-- Falls back to built-in Apex categories when no project file exists.
local function resolve_rulesets()
	local bufname = vim.api.nvim_buf_get_name(0)
	if bufname ~= "" then
		local root = vim.fs.root(bufname, "sfdx-project.json")
		if root then
			local project_rulesets = root .. "/apexRuleSets.xml"
			if vim.fn.filereadable(project_rulesets) == 1 then
				return project_rulesets
			end
		end
	end
	return "category/apex/errorprone.xml,category/apex/performance.xml,category/apex/bestpractices.xml,category/apex/security.xml,category/apex/codestyle.xml,category/apex/design.xml,category/apex/documentation.xml"
end

-- Parse PMD JSON output and map PMD priority → vim diagnostic severity.
-- PMD priority: 1 = Highest → ERROR, 2 = High → WARN, 3 = Medium → INFO,
--               4 = Low / 5 = Very Low → HINT
local function parse_pmd_json(output, bufnr, linter_cwd)
	local ok, data = pcall(vim.json.decode, output)
	if not ok or type(data) ~= "table" or not data.processingErrors then
		return {}
	end

	local diagnostics = {}
	for _, file in ipairs(data.files or {}) do
		for _, v in ipairs(file.violations or {}) do
			local severity = vim.diagnostic.severity.HINT
			local priority = tonumber(v.priority)
			if priority == 1 then
				severity = vim.diagnostic.severity.ERROR
			elseif priority == 2 then
				severity = vim.diagnostic.severity.WARN
			elseif priority == 3 then
				severity = vim.diagnostic.severity.INFO
			end

			table.insert(diagnostics, {
				lnum = math.max(0, (v.beginLine or 1) - 1),
				col = math.max(0, (v.beginColumn or 1) - 1),
				message = v.description or v.rule or "PMD violation",
				severity = severity,
				source = "pmd",
				code = v.rule,
			})
		end
	end
	return diagnostics
end

lint.linters.pmd_apex = {
	cmd = "pmd",
	stdin = false,
	args = {
		"check",
		"--format",
		"json",
		"--rulesets",
		"", -- placeholder; resolved per-project before try_lint()
		"--dir",
	},
	stream = "stdout",
	ignore_exitcode = true,
	parser = parse_pmd_json,
}

lint.linters_by_ft = {
	apex = { "pmd_apex" },
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
-- The rulesets placeholder is resolved per-project before each run.
vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "FileType" }, {
	callback = function(args)
		local ft = vim.bo[args.buf].filetype
		if ft == "apex" and lint.linters_by_ft[ft] then
			lint.linters.pmd_apex.args[5] = resolve_rulesets()
			lint.try_lint()
		end
	end,
})
