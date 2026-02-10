return {
	"zenibako/vim-fujjitive",
  config = function ()
    vim.cmd("let g:fujjitive_gitlab_domains = ['https://gitlab.odaseva.net']")
    -- vim.cmd("let g:gitlab_api_keys = {'gitlab.odaseva.net': '" .. vim.env.GITLAB_TOKEN .. "'}")
  end
}
