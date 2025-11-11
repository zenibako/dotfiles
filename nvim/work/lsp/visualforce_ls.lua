---@type vim.lsp.Config
return {
  cmd = {
    vim.fn.expand("$HOME/.local/share/nvim/mason/bin/visualforce-language-server"),
    "--stdio",
  },
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
