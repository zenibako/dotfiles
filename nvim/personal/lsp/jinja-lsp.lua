---@type vim.lsp.Config
return {
  cmd = { "jinja-lsp" },
  filetypes = { "jinja", "jinja2", "rust", "python" },
  root_markers = { ".git", "pyproject.toml", "Cargo.toml", "jinja-lsp.toml" },
  settings = {},
}
