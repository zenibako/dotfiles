vim.pack.add({
  "https://github.com/sindrets/diffview.nvim",
  "https://github.com/stevearc/dressing.nvim",
  "https://github.com/harrisoncramer/gitlab.nvim",
})

-- diffview must be fully loaded (plugin/ files sourced) before gitlab
-- because gitlab.nvim references the DiffviewGlobal set by diffview
pcall(vim.cmd.packadd, "diffview.nvim")
require("gitlab").setup()
