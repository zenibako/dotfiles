vim.keymap.set("n", "<leader>pv", "<cmd>lua MiniFiles.open()<CR>")

vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")
vim.keymap.set("n", "<leader>glmr", "<cmd>!glab mr create --web --no-editor --fill<CR>")
vim.keymap.set("n", "<leader>fr", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])

local function with_fzf(method)
  return function(...)
    local ok, fzf = pcall(require, "fzf-lua")
    if not ok then
      vim.notify("fzf-lua is not available yet", vim.log.levels.WARN)
      return
    end
    return fzf[method](...)
  end
end

vim.keymap.set("n", "<leader>pf", with_fzf("files"), {})
vim.keymap.set("n", "<leader>lg", with_fzf("live_grep"), {})
vim.keymap.set("n", "<C-p>", with_fzf("vcs_files"), {})
vim.keymap.set("n", "<leader>pws", with_fzf("grep_cword"), {})
vim.keymap.set("n", "<leader>pWs", with_fzf("grep_cWORD"), {})
vim.keymap.set("n", "<leader>fg", with_fzf("live_grep"), {})
vim.keymap.set("n", "<leader>vh", with_fzf("helptags"), {})
vim.keymap.set("n", "<leader>pp", with_fzf("builtin"), {})
vim.keymap.set("n", "<leader>gr", with_fzf("lsp_references"), {})
