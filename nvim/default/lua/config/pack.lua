-- Auto-confirm plugin installs (specs are explicitly listed; prompts are noise).
-- Patches vim.pack.add so that calls from lua/plugins/*.lua don't need to pass opts.
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

    if name == "go.nvim" then
      if not ev.data.active then
        vim.cmd.packadd("go.nvim")
      end
      require("go.install").update_all_sync()
    elseif name == "fff.nvim" then
      if vim.fn.executable("cargo") == 1 then
        local result = vim.system({ "cargo", "build", "--release" }, { cwd = ev.data.path }):wait()
        if result.code ~= 0 then
          vim.notify("fff.nvim: cargo build failed (exit " .. result.code .. ")", vim.log.levels.ERROR)
        end
      end
    elseif name == "gitlab.nvim" then
      if not ev.data.active then
        vim.cmd.packadd("gitlab.nvim")
      end
      require("gitlab.server").build(true)
    elseif name == "swagger-preview.nvim" then
      if vim.fn.executable("npm") == 1 then
        local result = vim.system({ "npm", "i" }, { cwd = ev.data.path }):wait()
        if result.code ~= 0 then
          vim.notify("swagger-preview.nvim: npm install failed (exit " .. result.code .. ")", vim.log.levels.ERROR)
        end
      end
    end
  end,
})

-- Core dependencies (must load before plugin configs that depend on them)
vim.pack.add({
  "https://github.com/nvim-lua/plenary.nvim",
  "https://github.com/nvim-tree/nvim-web-devicons",
  "https://github.com/b0o/schemastore.nvim",
})

-- Force core deps onto rtp now (vim.pack.add during init doesn't load by default)
for _, name in ipairs({"plenary.nvim", "nvim-web-devicons", "schemastore.nvim"}) do
  pcall(vim.cmd.packadd, name)
end

-- Auto-discover and load all plugin configs from lua/plugins/
local plugins_dir = vim.fn.stdpath("config") .. "/lua/plugins"
local files = vim.fn.glob(plugins_dir .. "/*.lua", true, true)
table.sort(files)
for _, file in ipairs(files) do
  local ok, err = pcall(dofile, file)
  if not ok then
    -- Defer the notify so a multi-line error during init.lua evaluation
    -- doesn't trigger the hit-enter prompt ("Press ENTER or type command to
    -- continue"). The full error is still available via :messages.
    local msg = "Error loading plugin config: " .. file .. "\n" .. err
    vim.schedule(function()
      vim.notify(msg, vim.log.levels.ERROR)
    end)
  end
end
