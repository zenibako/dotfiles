---@type vim.lsp.Config
return {
    cmd = { "sourcekit-lsp" },
    root_markers = { "Package.swift", ".git" },
    filetypes = { "swift", "objc", "objcpp" },
}
