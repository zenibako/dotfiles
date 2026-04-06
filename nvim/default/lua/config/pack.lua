-- Auto-confirm plugin installs (all plugins are explicitly listed in config)
local _pack_add = vim.pack.add
vim.pack.add = function(specs, opts)
  opts = vim.tbl_extend("keep", opts or {}, { confirm = false })
  return _pack_add(specs, opts)
end

-- PackChanged hooks for plugins that need build steps
-- Must be registered BEFORE vim.pack.add() calls
vim.api.nvim_create_autocmd("PackChanged", {
  callback = function(ev)
    local name = ev.data.spec.name
    local kind = ev.data.kind
    if kind ~= "install" and kind ~= "update" then
      return
    end

    if name == "nvim-treesitter" then
      if not ev.data.active then
        vim.cmd.packadd("nvim-treesitter")
      end
      vim.cmd("TSUpdate")
    elseif name == "go.nvim" then
      if not ev.data.active then
        vim.cmd.packadd("go.nvim")
      end
      require("go.install").update_all_sync()
    elseif name == "fff.nvim" then
      if vim.fn.executable("cargo") == 1 then
        vim.system({ "cargo", "build", "--release" }, { cwd = ev.data.path }):wait()
      end
    elseif name == "gitlab.nvim" then
      if not ev.data.active then
        vim.cmd.packadd("gitlab.nvim")
      end
      require("gitlab.server").build(true)
    elseif name == "swagger-preview.nvim" then
      if vim.fn.executable("npm") == 1 then
        vim.system({ "npm", "i" }, { cwd = ev.data.path }):wait()
      end
    end
  end,
})

-- Auto-discover and load all plugin configs from lua/plugins/
local plugins_dir = vim.fn.stdpath("config") .. "/lua/plugins"
local files = vim.fn.glob(plugins_dir .. "/*.lua", true, true)
table.sort(files)
for _, file in ipairs(files) do
  local ok, err = pcall(dofile, file)
  if not ok then
    vim.notify("Error loading plugin config: " .. file .. "\n" .. err, vim.log.levels.ERROR)
  end
end
