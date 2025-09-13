return {
	"echasnovski/mini.nvim",
	version = false,
	config = function()
		require("mini.ai").setup()
		require("mini.files").setup({
      mappings = {
        go_in_plus = "<CR>",
      },
      windows = {
        preview = true,
        width_focus = 50,
        width_nofocus = 15,
        width_preview = 50,
      },
    })
		require("mini.move").setup()
		require("mini.operators").setup()
		require("mini.pairs").setup()
		require("mini.surround").setup()
    require("mini.snippets").setup()
		require("mini.tabline").setup()
    require("mini.fuzzy").setup()
	end,
}
