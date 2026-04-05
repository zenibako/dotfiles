vim.pack.add({
  "https://github.com/nvimtools/none-ls-extras.nvim",
  "https://github.com/nvimtools/none-ls.nvim",
})

local null_ls = require("null-ls")

null_ls.setup({
  sources = {
    null_ls.builtins.formatting.stylua,
    null_ls.builtins.formatting.prettier.with({
      extra_filetypes = { "apex" },
      extra_args = {
        "--plugin=prettier-plugin-apex",
      },
    }),
    require("none-ls.diagnostics.eslint"),
    null_ls.builtins.formatting.xmllint,
  },
})
