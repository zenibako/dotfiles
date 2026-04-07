-- Synchronously install the apex tree-sitter parser via nvim-treesitter and
-- exit non-zero on any failure. Used by the Validate workflow to make sure
-- the Apex parser actually compiles in CI (the VimEnter install autocmd in
-- nvim/default/lua/plugins/treesitter.lua runs async and swallows errors).

local ok_plugin, nts = pcall(require, "nvim-treesitter")
if not ok_plugin then
  io.stderr:write("nvim-treesitter not available: " .. tostring(nts) .. "\n")
  os.exit(1)
end

local ok, err = pcall(function()
  nts.install({ "apex" }):wait(290000)
end)
if not ok then
  io.stderr:write("apex install failed: " .. tostring(err) .. "\n")
  os.exit(1)
end
