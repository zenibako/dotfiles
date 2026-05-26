vim.pack.add({
	"https://github.com/mfussenegger/nvim-lint",
})

local lint = require("lint")

-- Parse code-analyzer JSON output (sf code-analyzer run --output-format json),
-- filter to current-buffer violations only, and map severity (1-5) →
-- vim diagnostic severity.
-- JSON shape: { runDir, violations: [{ rule, engine, severity, locations: [{ file, startLine, startColumn, endLine, endColumn }], message }] }
local function parse_ca_json(output, bufnr, linter_cwd)
	local ok, data = pcall(vim.json.decode, output)
	if not ok or type(data) ~= "table" then
		return {}
	end

	local bufname = vim.api.nvim_buf_get_name(bufnr)
	local bufpath = vim.fn.fnamemodify(bufname, ":p")
	local run_dir = data.runDir or (linter_cwd or vim.fn.getcwd()) .. "/"

	local function resolve_path(name)
		if not name or name == "" then
			return ""
		end
		if vim.startswith(name, "/") then
			return vim.fn.fnamemodify(name, ":p")
		end
		return vim.fn.fnamemodify(run_dir .. name, ":p")
	end

	local diagnostics = {}
	for _, v in ipairs(data.violations or {}) do
		local pri_idx = (v.primaryLocationIndex or 0) + 1
		local loc = (v.locations or {})[pri_idx] or (v.locations or {})[1]
		if not loc then
			goto continue
		end

		local filepath = resolve_path(loc.file)
		if filepath ~= bufpath then
			goto continue
		end

		local severity = vim.diagnostic.severity.HINT
		local sev = tonumber(v.severity)
		if sev == 1 or sev == 2 then
			severity = vim.diagnostic.severity.ERROR
		elseif sev == 3 then
			severity = vim.diagnostic.severity.WARN
		elseif sev == 4 then
			severity = vim.diagnostic.severity.INFO
		end

		-- Make diagnostics single-line so virtual_lines renders at the
		-- start line (Neovim places virtual_lines at end_lnum).
		local lnum = math.max(0, (loc.startLine or 1) - 1)
		table.insert(diagnostics, {
			lnum = lnum,
			col = math.max(0, (loc.startColumn or 1) - 1),
			end_lnum = lnum,
			end_col = math.max(0, (loc.endColumn or loc.startColumn or 1) - 1),
			message = v.message or v.rule or "code-analyzer violation",
			severity = severity,
			source = "code-analyzer",
			code = v.rule,
		})

		::continue::
	end
	return diagnostics
end

lint.linters.code_analyzer_apex = {
	cmd = "sh",
	stdin = false,
	args = {}, -- built dynamically per-buffer in the autocmd
	stream = "stdout",
	ignore_exitcode = true,
	parser = parse_ca_json,
	timeout = 60000, -- 60s; code-analyzer can be slow on first run
}

lint.linters_by_ft = {
	apex = { "code_analyzer_apex" },
}

-- Warn once per session if sf CLI is not installed when opening an Apex file.
local ca_warned = false
vim.api.nvim_create_autocmd("FileType", {
	pattern = "apex",
	callback = function()
		if not ca_warned and vim.fn.executable("sf") == 0 then
			ca_warned = true
			vim.notify(
				"Salesforce CLI (sf) not found in PATH. Apex diagnostics will not work.\n"
					.. "Install it from https://developer.salesforce.com/tools/salesforcecli",
				vim.log.levels.WARN,
				{ title = "nvim-lint (code-analyzer)" }
			)
		end
	end,
})

-- Trigger linting on save, read, and filetype detection.
-- Build args dynamically per buffer; sf code-analyzer writes JSON to a temp
-- file, so we cat it to stdout where nvim-lint reads it.
vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "FileType" }, {
	callback = function(args)
		local ft = vim.bo[args.buf].filetype
		if ft == "apex" and lint.linters_by_ft[ft] then
			local bufname = vim.api.nvim_buf_get_name(args.buf)
			if bufname ~= "" then
				local root = vim.fs.root(bufname, "sfdx-project.json")
					or vim.fn.fnamemodify(bufname, ":h")
				local tmpfile = vim.fn.tempname() .. ".json"

				lint.linters.code_analyzer_apex.args = {
					"-c",
					string.format(
						"sf code-analyzer run --target %s --workspace %s --output-file %s 2>/dev/null && cat %s; rm -f %s",
						vim.fn.shellescape(bufname),
						vim.fn.shellescape(root),
						vim.fn.shellescape(tmpfile),
						vim.fn.shellescape(tmpfile),
						vim.fn.shellescape(tmpfile)
					),
				}
			end
			lint.try_lint()
		end
	end,
})
