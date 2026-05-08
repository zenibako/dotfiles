-- Auto-discover the Apex JAR from the VS Code Salesforce extension.
-- This is update-proof: it always picks the latest installed version.
local function discover_apex_jar()
	local matches = vim.fn.glob(vim.fn.expand("~/.vscode/extensions/salesforce.salesforcedx-vscode-apex-*/out/apex-jorje-lsp.jar"), false, true)
	if not matches or #matches == 0 then
		matches = vim.fn.glob(vim.fn.expand("~/.vscode/extensions/salesforce.salesforcedx-vscode-apex-*/apex-jorje-lsp.jar"), false, true)
	end
	if not matches or #matches == 0 then
		return nil
	end
	-- Sort to prefer the latest versioned directory
	table.sort(matches)
	return matches[#matches]
end

local config = {
	filetypes = { "java", "trigger", "apex", "apexcode" },
	root_markers = { "sfdx-project.json" },
	apex_jar_path = discover_apex_jar(),
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
