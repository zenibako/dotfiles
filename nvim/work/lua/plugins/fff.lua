vim.pack.add({"https://github.com/dmtrKovalenko/fff.nvim"})

-- fff.nvim requires a Rust binary built via `cargo build --release`.
-- Skip setup if the binary isn't available yet (first install).
local ok, fff = pcall(require, "fff")
if ok then
  fff.setup({})
end

vim.keymap.set("n", "ff", function()
  require("fff").find_files()
end, { desc = "Open file picker" })
