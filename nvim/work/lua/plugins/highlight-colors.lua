return {
  "brenoprata10/nvim-highlight-colors",
  setup = function ()
    -- Ensure termguicolors is enabled if not already
    require('nvim-highlight-colors').setup({})
  end
}
