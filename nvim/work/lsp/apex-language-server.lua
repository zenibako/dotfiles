-- Auto-discover the Apex JAR from the VS Code Salesforce extension.
-- This is update-proof: it always picks the latest installed version.
-- Debug: set $NVIM_APEX_JAR_DEBUG=1 to see discovery details.
local function discover_apex_jar()
	local home = vim.uv.os_homedir() or os.getenv("HOME") or os.getenv("USERPROFILE")
	if not home then
		return nil
	end

	local ext_path = home .. "/.vscode/extensions/salesforce.salesforcedx-vscode-apex-*"
	local ext_dirs = vim.fn.glob(ext_path, false, true)

	local debug = os.getenv("NVIM_APEX_JAR_DEBUG") == "1"
	if debug then
		vim.notify("Apex JAR discovery: searching " .. ext_path, vim.log.levels.DEBUG)
		vim.notify("Apex JAR discovery: found " .. tostring(#(ext_dirs or {})) .. " extension dirs", vim.log.levels.DEBUG)
	end

	if not ext_dirs or #ext_dirs == 0 then
		return nil
	end

	-- Sort to prefer the latest versioned directory
	table.sort(ext_dirs)
	local latest = ext_dirs[#ext_dirs]

	if debug then
		vim.notify("Apex JAR discovery: latest dir = " .. latest, vim.log.levels.DEBUG)
	end

	local candidate_paths = {
		latest .. "/dist/apex-jorje-lsp.jar",
		latest .. "/out/apex-jorje-lsp.jar",
		latest .. "/apex-jorje-lsp.jar",
	}

	for _, p in ipairs(candidate_paths) do
		if vim.fn.filereadable(p) == 1 then
			if debug then
				vim.notify("Apex JAR discovery: found " .. p, vim.log.levels.DEBUG)
			end
			return p
		elseif debug then
			vim.notify("Apex JAR discovery: not found at " .. p, vim.log.levels.DEBUG)
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
