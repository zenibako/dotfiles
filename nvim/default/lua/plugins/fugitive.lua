return {
	url = "https://tpope.io/vim/fugitive.git",
  config = function ()
    vim.cmd("let g:fugitive_gitlab_domains = ['https://gitlab.odaseva.net']")
    -- vim.cmd("let g:gitlab_api_keys = {'gitlab.odaseva.net': '" .. vim.env.GITLAB_TOKEN .. "'}")
  end
}
