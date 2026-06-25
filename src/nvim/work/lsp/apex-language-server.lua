-- Auto-discover the Apex JAR from the VS Code Salesforce extension.
-- Override: set $NVIM_APEX_JAR_PATH to skip auto-discovery entirely.
local function discover_apex_jar()
	local override = os.getenv("NVIM_APEX_JAR_PATH")
	if override and override ~= "" then
		return override
	end

	local homes = {}
	local function add_home(h)
		if h and h ~= "" then
			for _, e in ipairs(homes) do
				if e == h then return end
			end
			table.insert(homes, h)
		end
	end

	-- Gather every plausible home directory
	add_home(vim.uv.os_homedir())
	add_home(os.getenv("HOME"))
	add_home(os.getenv("USERPROFILE"))

	-- macOS: GUI apps sometimes resolve os_homedir() to the long display-name
	-- path (e.g. /Users/chandler.anderson) while VS Code extensions are
	-- installed under the short username path (/Users/chanderson). Derive the
	-- short path from $USER as a fallback.
	local user = os.getenv("USER") or os.getenv("USERNAME")
	if user and user ~= "" then
		add_home("/Users/" .. user)
		add_home("/home/" .. user)
	end

	for _, home in ipairs(homes) do
		local ext_dir = home .. "/.vscode/extensions"
		if vim.fn.isdirectory(ext_dir) == 0 then
			goto next_home
		end

		local pattern = ext_dir .. "/salesforce.salesforcedx-vscode-apex-*"
		local matches = vim.fn.glob(pattern, false, true)

		local dirs = {}
		for _, m in ipairs(matches) do
			if vim.fn.isdirectory(m) == 1 and m:match("salesforcedx%-vscode%-apex%-%d") then
				table.insert(dirs, m)
			end
		end

		if #dirs == 0 then
			goto next_home
		end

		table.sort(dirs)
		local latest = dirs[#dirs]

		local candidates = {
			latest .. "/dist/apex-jorje-lsp.jar",
			latest .. "/out/apex-jorje-lsp.jar",
			latest .. "/apex-jorje-lsp.jar",
		}

		for _, p in ipairs(candidates) do
			if vim.fn.filereadable(p) == 1 then
				return p
			end
		end

		::next_home::
	end

	return nil
end

local apex_jar_path = discover_apex_jar()

-- Warn once per session when opening an Apex file if the JAR is missing.
if not apex_jar_path then
	vim.api.nvim_create_autocmd("FileType", {
		pattern = { "apex", "java", "trigger", "apexcode" },
		callback = function()
			local homes = {}
			local function add(h)
				if h and h ~= "" then
					for _, e in ipairs(homes) do if e == h then return end end
					table.insert(homes, h)
				end
			end
			add(vim.uv.os_homedir())
			add(os.getenv("HOME"))
			add(os.getenv("USERPROFILE"))
			local user = os.getenv("USER") or os.getenv("USERNAME")
			if user then
				add("/Users/" .. user)
				add("/home/" .. user)
			end

			local searched = {}
			for _, h in ipairs(homes) do
				table.insert(searched, h .. "/.vscode/extensions/salesforce.salesforcedx-vscode-apex-*/{dist,out}/apex-jorje-lsp.jar")
			end

			vim.notify(
				"Apex Language Server: apex-jorje-lsp.jar not found.\n"
					.. "Searched:\n  - " .. table.concat(searched, "\n  - ") .. "\n\n"
					.. "Override: export NVIM_APEX_JAR_PATH=/path/to/apex-jorje-lsp.jar\n"
					.. "Please install the Salesforce VS Code extension: salesforce.salesforcedx-vscode-apex",
				vim.log.levels.WARN,
				{ title = "Apex LSP" }
			)
		end,
		once = true,
	})
end

local config = {
	-- "java" intentionally omitted: jorje would otherwise attach to real Java
	-- files and parse them as Apex. Apex sources resolve to apex/apexcode.
	filetypes = { "trigger", "apex", "apexcode" },
	root_markers = { "sfdx-project.json" },
	apex_jar_path = apex_jar_path,
	apex_enable_semantic_errors = false,
	apex_enable_completion_statistics = true,
}

if not config.cmd and config.apex_jar_path then
	config.cmd = {
		vim.env.JAVA_HOME and (vim.env.JAVA_HOME .. "/bin/java") or "java",
		"-cp",
		config.apex_jar_path,
		"-Ddebug.internal.errors=true",
		"-Ddebug.semantic.errors=" .. tostring(config.apex_enable_semantic_errors or false),
		"-Ddebug.completion.statistics=" .. tostring(config.apex_enable_completion_statistics or false),
		"-Dlwc.typegeneration.disabled=true",
	}
	if config.apex_jvm_max_heap then
		table.insert(config.cmd, "-Xmx" .. config.apex_jvm_max_heap)
	end
	table.insert(config.cmd, "apex.jorje.lsp.ApexLanguageServerLauncher")
end

---@type vim.lsp.Config
return config
