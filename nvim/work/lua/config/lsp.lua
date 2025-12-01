-- Load Salesforce filetype detection BEFORE enabling LSPs
require("config.salesforce")

vim.lsp.enable({
  "apex-language-server",
  "gitlab_ci_ls",
  "gopls",
  "html",
  "jsonls",
  "lua_ls",
  "lwc_ls",
  "terraformls",
  "ts_ls",
  "visualforce_ls",
  "yamlls",
  "cuelang",
})

