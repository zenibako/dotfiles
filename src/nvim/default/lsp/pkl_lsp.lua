---@type vim.lsp.Config
return {
  cmd = { "pkl-lsp" },
  filetypes = { "pkl" },
  root_markers = { "PklProject", ".git" },
  single_file_support = true,
}
