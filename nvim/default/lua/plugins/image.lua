vim.pack.add({
  "https://github.com/3rd/image.nvim",
  "https://github.com/3rd/diagram.nvim",
})

local mermaid_integration = require("config.diagram_mermaid")

require("image").setup({
  processor = "magick_cli",
})

require("diagram").setup({
  renderer_options = {
    mermaid = {
      scale = 2,
    },
  },
  integrations = {
    require("diagram.integrations.markdown"),
  },
})

vim.keymap.set("n", "<leader>dh", function()
  if vim.bo.filetype == "mermaid" then
    mermaid_integration.open_current_buffer_svg()
    return
  end
  require("diagram").show_diagram_hover()
end, { desc = "Show diagram hover" })
