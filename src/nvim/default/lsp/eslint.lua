-- Diagnostics and code actions from the project's own eslint config.
-- Rooted on eslint config files only, so it stays silent in projects
-- without one. Formatting stays with prettier (format = false).
---@type vim.lsp.Config
return {
  cmd = { "vscode-eslint-language-server", "--stdio" },
  filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact", "vue", "astro" },
  root_markers = {
    "eslint.config.js",
    "eslint.config.mjs",
    "eslint.config.cjs",
    ".eslintrc.js",
    ".eslintrc.cjs",
    ".eslintrc.json",
    ".eslintrc.yaml",
    ".eslintrc.yml",
  },
  -- The server errors without workspaceFolder in settings (matches
  -- nvim-lspconfig's eslint before_init).
  before_init = function(_, config)
    local root = config.root_dir
    if root then
      config.settings = config.settings or {}
      config.settings.workspaceFolder = {
        uri = root,
        name = vim.fn.fnamemodify(root, ":t"),
      }
    end
  end,
  settings = {
    validate = "on",
    useESLintClass = false,
    experimental = { useFlatConfig = false },
    codeActionOnSave = { enable = false, mode = "all" },
    format = false,
    quiet = false,
    onIgnoredFiles = "off",
    rulesCustomizations = {},
    run = "onType",
    problems = { shortenToSingleLine = false },
    nodePath = "",
    workingDirectory = { mode = "location" },
    codeAction = {
      disableRuleComment = { enable = true, location = "separateLine" },
      showDocumentation = { enable = true },
    },
  },
}
