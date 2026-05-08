-- Auto-discover the Apex JAR from the VS Code Salesforce extension.
-- Override: set $NVIM_APEX_JAR_PATH to skip auto-discovery entirely.
-- Debug: set $NVIM_APEX_JAR_DEBUG=1 to see discovery details.
local function discover_apex_jar()
	-- 1. Respect explicit override
	local override = os.getenv("NVIM_APEX_JAR_PATH")
	if override and override ~= "" then
		return override
	end

	-- 2. Resolve home directory (multiple fallbacks)
	local home = vim.uv.os_homedir() or os.getenv("HOME") or os.getenv("USERPROFILE")
	if not home then
		return nil
	end

	local ext_dir = home .. "/.vscode/extensions"
	local debug = os.getenv("NVIM_APEX_JAR_DEBUG") == "1"

	if debug then
		vim.notify("Apex JAR: home=" .. home, vim.log.levels.DEBUG)
		vim.notify("Apex JAR: scanning " .. ext_dir, vim.log.levels.DEBUG)
	end

	-- 3. Scan the extensions directory
	local handle = vim.uv.fs_scandir(ext_dir)
	if not handle then
		if debug then
			vim.notify("Apex JAR: cannot open " .. ext_dir, vim.log.levels.DEBUG)
		end
		return nil
	end

	local matches = {}
	while true do
		local name, typ = vim.uv.fs_scandir_next(handle)
		if not name then
			break
		end
		if typ == "directory" and name:match("^salesforce%.salesforcedx%-vscode%-apex%-") then
			table.insert(matches, ext_dir .. "/" .. name)
		end
	end

	if debug then
		vim.notify("Apex JAR: found " .. tostring(#matches) .. " dirs", vim.log.levels.DEBUG)
		for _, m in ipairs(matches) do
			vim.notify("Apex JAR:   - " .. m, vim.log.levels.DEBUG)
		end
	end

	if #matches == 0 then
		return nil
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
		-- Use io.open as the most reliable existence check across platforms
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

	return nil
end

local apex_jar_path = discover_apex_jar()

-- Warn once per session when opening an Apex file if the JAR is missing.
-- This avoids spamming the user at startup for unrelated filetypes.
if not apex_jar_path then
	vim.api.nvim_create_autocmd("FileType", {
		pattern = { "apex", "java", "trigger", "apexcode" },
		callback = function()
			local home = vim.uv.os_homedir() or os.getenv("HOME") or os.getenv("USERPROFILE")
			local searched = home and (home .. "/.vscode/extensions/salesforce.salesforcedx-vscode-apex-*/{dist,out}/apex-jorje-lsp.jar") or "~/.vscode/extensions/..."
			vim.notify(
				"Apex Language Server: apex-jorje-lsp.jar not found.\n"
					.. "Searched: " .. searched .. "\n"
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
