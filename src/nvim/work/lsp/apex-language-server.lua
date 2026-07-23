-- Apex jorje LSP. The jar is unpacked from the pinned Salesforce VSIX by
-- scripts/lsp_vsix_sync.sh (dotfiles repo) into ~/.local/share/lsp-servers/ —
-- VS Code is not involved and need not be installed.
-- Override: set $NVIM_APEX_JAR_PATH to skip the managed path entirely.
local MANAGED_JAR = "~/.local/share/lsp-servers/salesforcedx-vscode-apex/dist/apex-jorje-lsp.jar"

local function discover_apex_jar()
	local override = os.getenv("NVIM_APEX_JAR_PATH")
	if override and override ~= "" then
		return override
	end
	local jar = vim.fn.expand(MANAGED_JAR)
	if vim.fn.filereadable(jar) == 1 then
		return jar
	end
	return nil
end

local apex_jar_path = discover_apex_jar()

-- Warn once per session when opening an Apex file if the JAR is missing.
if not apex_jar_path then
	vim.api.nvim_create_autocmd("FileType", {
		pattern = { "apex", "java", "trigger", "apexcode" },
		callback = function()
			vim.notify(
				"Apex Language Server: apex-jorje-lsp.jar not found.\n"
					.. "Expected: " .. MANAGED_JAR .. "\n\n"
					.. "Fetch it: run scripts/lsp_vsix_sync.sh in the dotfiles repo.\n"
					.. "Override: export NVIM_APEX_JAR_PATH=/path/to/apex-jorje-lsp.jar",
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
