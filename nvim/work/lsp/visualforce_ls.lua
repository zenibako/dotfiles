-- @salesforce/visualforce-language-server is published to npm. Run via npx so
-- we don't need a Mason install. For faster startup, install globally with:
--   pnpm add -g @salesforce/visualforce-language-server
-- and replace the cmd below with { "visualforce-language-server", "--stdio" }.
---@type vim.lsp.Config
return {
  cmd = { "npx", "-y", "@salesforce/visualforce-language-server", "--stdio" },
  filetypes = { "visualforce", "page", "component" },
  root_markers = { "sfdx-project.json" },
  init_options = {
    embeddedLanguages = {
      css = true,
      javascript = true,
    },
    provideFormatter = true,
  },
  settings = {
    html = {
      format = {
        enable = true,
        wrapLineLength = 120,
        wrapAttributes = "auto",
        indentInnerHtml = false,
        preserveNewLines = true,
        maxPreserveNewLines = 2,
        indentHandlebars = false,
        endWithNewline = true,
        extraLiners = "head, body, /html",
        templating = false,
      },
      suggest = {
        html5 = true,
      },
      validate = {
        scripts = true,
        styles = true,
      },
      autoClosingTags = true,
      mirrorCursorOnMatchingTag = false,
    },
  },
}
