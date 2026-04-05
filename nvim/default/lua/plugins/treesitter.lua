vim.pack.add("https://github.com/nvim-treesitter/nvim-treesitter")

require("nvim-treesitter").setup({})

-- Install parsers (no-op if already installed)
require("nvim-treesitter").install({
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

-- Register custom parsers via TSUpdate autocmd
vim.api.nvim_create_autocmd("User", {
  pattern = "TSUpdate",
  callback = function()
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
