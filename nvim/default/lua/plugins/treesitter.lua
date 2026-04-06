vim.pack.add({"https://github.com/nvim-treesitter/nvim-treesitter"})

require("nvim-treesitter").setup({})

-- Register custom parsers so they're available at startup and during TSUpdate
local parsers = require("nvim-treesitter.parsers")

parsers.templ = {
  install_info = {
    url = "https://github.com/vrischmann/tree-sitter-templ.git",
    branch = "master",
  },
}

parsers.fountain = {
  install_info = {
    url = "https://github.com/zenibako/tree-sitter-fountain",
    branch = "master",
  },
}

-- Install parsers after startup (no-op if already installed).
-- Requires tree-sitter CLI on PATH; skip if unavailable.
vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    if vim.fn.executable("tree-sitter") ~= 1 then
      return
    end
    require("nvim-treesitter").install({
      "templ",
      "fountain",
      "c",
      "vimdoc",
      "apex",
      "soql",
      "sosl",
      "jsdoc",
      "json",
      "javascript",
      "typescript",
      "tsx",
      "yaml",
      "html",
      "css",
      "markdown",
      "markdown_inline",
      "bash",
      "lua",
      "vim",
      "dockerfile",
      "gitignore",
      "query",
    })
  end,
})

-- Enable treesitter highlighting for all filetypes with available parsers
vim.api.nvim_create_autocmd("FileType", {
  callback = function()
    pcall(vim.treesitter.start)
  end,
})

vim.filetype.add({
  extension = {
    fountain = "fountain",
  },
})

vim.treesitter.language.register("templ", "templ")

-- Use HTML treesitter parser for Visualforce files
vim.treesitter.language.register("html", "visualforce")
