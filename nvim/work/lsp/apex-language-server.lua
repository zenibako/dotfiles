-- Auto-discover the Apex JAR from the VS Code Salesforce extension.
-- Override: set $NVIM_APEX_JAR_PATH to skip auto-discovery entirely.
-- Debug: set $NVIM_APEX_JAR_DEBUG=1 to see discovery details.

---@return string|nil
local function discover_apex_jar()
	-- 1. Respect explicit override
	local override = os.getenv("NVIM_APEX_JAR_PATH")
	if override and override ~= "" then
		return override
	end

	local debug = os.getenv("NVIM_APEX_JAR_DEBUG") == "1"

	-- 2. Collect candidate home directories
	local homes = {}
	local function add_home(h)
		if h and h ~= "" then
			for _, existing in ipairs(homes) do
				if existing == h then
					return
				end
			end
			table.insert(homes, h)
		end
	end

	-- Try multiple sources for home directory
	add_home(vim.uv.os_homedir())
	add_home(os.getenv("HOME"))
	add_home(os.getenv("USERPROFILE"))

	-- macOS: sometimes os_homedir() returns the display name path
	-- while $HOME returns the short username path; try both
	if os.getenv("HOME") and os.getenv("HOME") ~= (vim.uv.os_homedir() or "") then
		-- Already added above, but try deriving alternatives
		local short_home = os.getenv("HOME")
		-- If HOME is /Users/shortname, also try /Users/longname if different
		local long_user = os.getenv("USER") or os.getenv("USERNAME")
		if long_user and long_user ~= "" then
			local alt = "/Users/" .. long_user
			add_home(alt)
		end
	end

	-- 3. Scan each home directory for the extension
	for _, home in ipairs(homes) do
		local ext_dir = home .. "/.vscode/extensions"

		if debug then
			vim.notify("Apex JAR: scanning " .. ext_dir, vim.log.levels.DEBUG)
		end

		-- Use io.popen with ls for reliable cross-platform directory listing
		local handle = io.popen('ls -1 "' .. ext_dir .. '" 2>/dev/null')
		if not handle then
			goto continue_home
		end

		local matches = {}
		for name in handle:lines() do
			if name:match("^salesforce%.salesforcedx%-vscode%-apex%-") then
				-- Verify it's actually a directory
				local dir_path = ext_dir .. "/" .. name
				local stat = vim.uv.fs_stat(dir_path)
				if stat and stat.type == "directory" then
					table.insert(matches, dir_path)
				end
			end
		end
		handle:close()

		if debug then
			vim.notify("Apex JAR: found " .. tostring(#matches) .. " dirs in " .. ext_dir, vim.log.levels.DEBUG)
			for _, m in ipairs(matches) do
				vim.notify("Apex JAR:   - " .. m, vim.log.levels.DEBUG)
			end
		end

		if #matches == 0 then
			goto continue_home
		end

		-- 4. Prefer the latest versioned directory
		table.sort(matches)
		local latest = matches[#matches]

		-- 5. Check known JAR locations
		local candidate_paths = {
			latest .. "/dist/apex-jorje-lsp.jar",
			latest .. "/out/apex-jorje-lsp.jar",
			latest .. "/apex-jorje-lsp.jar",
		}

		for _, p in ipairs(candidate_paths) do
			local f = io.open(p, "r")
			if f then
				f:close()
				if debug then
					vim.notify("Apex JAR: found " .. p, vim.log.levels.DEBUG)
				end
				return p
			elseif debug then
				vim.notify("Apex JAR: not found at " .. p, vim.log.levels.DEBUG)
			end
		end

		::continue_home::
	end

	return nil
end

local apex_jar_path = discover_apex_jar()

-- Warn once per session when opening an Apex file if the JAR is missing.
-- This avoids spamming the user at startup for unrelated filetypes.
if not apex_jar_path then
	vim.api.nvim_create_autocmd("FileType", {
		pattern = { "apex", "java", "trigger", "apexcode" },
		callback = function()
			local homes = {}
			local function add(h)
				if h and h ~= "" then
					for _, e in ipairs(homes) do
						if e == h then
							return
						end
					end
					table.insert(homes, h)
				end
			end
			add(vim.uv.os_homedir())
			add(os.getenv("HOME"))
			add(os.getenv("USERPROFILE"))

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
	filetypes = { "java", "trigger", "apex", "apexcode" },
	root_markers = { "sfdx-project.json" },
	apex_jar_path = apex_jar_path,
	apex_enable_semantic_errors = false, -- Disabled: PMD/SonarLint now provide Apex diagnostics
	apex_enable_completion_statistics = true, -- Whether to allow Apex Language Server to collect telemetry on code completion usage
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
