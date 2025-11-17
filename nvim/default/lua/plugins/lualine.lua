return {
	'nvim-lualine/lualine.nvim',
	requires = {
		'kyazdani42/nvim-web-devicons',
		opt = true,
	},
	config = function()
		require('lualine').setup({
			options = {
				theme = '{{ nvim_lualine_theme }}',
			},
		})
	end
}
