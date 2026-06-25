---@type vim.lsp.Config
return {
  cmd = { "yaml-language-server", "--stdio" },
  -- `yaml.gitlab` intentionally omitted: gitlab_ci_ls owns GitLab CI files
  -- (avoids duplicate completion/diagnostics from two servers on one buffer).
  filetypes = { "yaml", "yaml.docker-compose" },
  root_markers = { ".git" },
  single_file_support = true,
  settings = {
    -- https://github.com/redhat-developer/vscode-redhat-telemetry#how-to-disable-telemetry-reporting
    redhat = { telemetry = { enabled = false } },
    yaml = {
      schemaStore = {
        -- You must disable built-in schemaStore support if you want to use
        -- this plugin and its advanced options like `ignore`.
        enable = false,
        -- Avoid TypeError: Cannot read properties of undefined (reading 'length')
        url = "",
      },
      schemas = require("schemastore").yaml.schemas(),
    },
  },
}
