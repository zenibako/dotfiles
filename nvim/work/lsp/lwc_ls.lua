-- @salesforce/lwc-language-server is published to npm. Run via npx so we don't
-- need a Mason install. For faster startup, install globally with:
--   pnpm add -g @salesforce/lwc-language-server
-- and replace the cmd below with { "lwc-language-server", "--stdio" }.
---@type vim.lsp.Config
return {
  cmd = { "npx", "-y", "@salesforce/lwc-language-server", "--stdio" },
  filetypes = { "javascript", "html" },
  root_markers = { "sfdx-project.json" },
  init_options = {
    embeddedLanguages = {
      javascript = true,
    },
  },
}
