vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = "*.gitlab-ci*.{yml,yaml}",
  callback = function()
    vim.bo.filetype = "yaml.gitlab"
  end,
})

local cache_dir = os.getenv("HOME") .. "/.cache/gitlab-ci-ls/"

---@type vim.lsp.Config
return {
  cmd = { "gitlab-ci-ls" },
  filetypes = { "yaml.gitlab" },
  root_markers = { ".gitlab*", ".git" },
  init_options = {
    cache_path = cache_dir,
    log_path = cache_dir .. "/log/gitlab-ci-ls.log",
  },
}
