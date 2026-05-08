vim.pack.add({
	"https://github.com/mfussenegger/nvim-lint",
})

local lint = require("lint")

-- Resolve rulesets: prefer project-local apexRuleSets.xml.
-- Falls back to built-in Apex categories when no project file exists.
local function resolve_rulesets(bufnr)
	local bufname = vim.api.nvim_buf_get_name(bufnr)
	if bufname ~= "" then
		local root = vim.fs.root(bufname, "sfdx-project.json")
		if root then
			local project_rulesets = root .. "/apexRuleSets.xml"
			if vim.fn.filereadable(project_rulesets) == 1 then
				-- Use project rulesets in addition to built-in categories for consistent coverage
				return project_rulesets .. ",category/apex/errorprone.xml,category/apex/performance.xml,category/apex/bestpractices.xml,category/apex/security.xml,category/apex/codestyle.xml,category/apex/design.xml,category/apex/documentation.xml"
			end
		end
	end
	-- Fallback: always include all built-in categories plus project file if present
	local fallback = "category/apex/errorprone.xml,category/apex/performance.xml,category/apex/bestpractices.xml,category/apex/security.xml,category/apex/codestyle.xml,category/apex/design.xml,category/apex/documentation.xml"
	return fallback
end

-- Parse PMD JSON output, filter to current-buffer violations only, and map
-- PMD priority → vim diagnostic severity.
-- NOTE: PMD JSON keys are lowercase: beginline, begincolumn, endline, endcolumn
local function parse_pmd_json(output, bufnr, linter_cwd)
	local ok, data = pcall(vim.json.decode, output)
	if not ok or type(data) ~= "table" then
		return {}
	end

	local bufname = vim.api.nvim_buf_get_name(bufnr)
	local bufpath = vim.fn.fnamemodify(bufname, ":p")

	local function resolve_path(name)
		if not name or name == "" then
			return ""
		end
		if vim.startswith(name, "/") then
			return vim.fn.fnamemodify(name, ":p")
		end
		local base = linter_cwd or vim.fn.getcwd()
		return vim.fn.fnamemodify(base .. "/" .. name, ":p")
	end

	local diagnostics = {}
	for _, file in ipairs(data.files or {}) do
		local filepath = resolve_path(file.filename)
		if filepath == bufpath then
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

				-- PMD JSON uses lowercase keys: beginline, begincolumn, etc.
				table.insert(diagnostics, {
					lnum = math.max(0, (v.beginline or 1) - 1),
					col = math.max(0, (v.begincolumn or 1) - 1),
					end_lnum = (v.endline or v.beginline or 1) - 1,
					end_col = (v.endcolumn or v.begincolumn or 1) - 1,
					message = v.description or v.rule or "PMD violation",
					severity = severity,
					source = "pmd",
					code = v.rule,
				})
			end
		end
	end
	return diagnostics
end

lint.linters.pmd_apex = {
	cmd = "pmd",
	stdin = false,
	args = {}, -- built dynamically per-buffer in the autocmd
	stream = "stdout",
	ignore_exitcode = true,
	parser = parse_pmd_json,
	timeout = 30000, -- 30s; PMD can be slow on first run
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
-- Build args dynamically per buffer so --dir points at the file's directory.
vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "FileType" }, {
	callback = function(args)
		local ft = vim.bo[args.buf].filetype
		if ft == "apex" and lint.linters_by_ft[ft] then
			local bufname = vim.api.nvim_buf_get_name(args.buf)
			if bufname ~= "" then
				local dir = vim.fn.fnamemodify(bufname, ":h")
				local cache = vim.fn.stdpath("cache") .. "/pmd"
				vim.fn.mkdir(cache, "p")

				lint.linters.pmd_apex.args = {
					"check",
					"--format", "json",
					"--rulesets", resolve_rulesets(args.buf),
					"--dir", dir,
					"--cache", cache,
				}
			end
			lint.try_lint()
		end
	end,
})
