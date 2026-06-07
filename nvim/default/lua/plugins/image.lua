vim.pack.add({
  "https://github.com/3rd/image.nvim",
  "https://github.com/3rd/diagram.nvim",
})

local mermaid_integration = require("config.diagram_mermaid")

local function resolve_markdown_image_path(document_path, image_path, fallback)
  local resolved = fallback(document_path, image_path)
  if not resolved:lower():match("%.svg$") then
    return resolved
  end

  local source_stat = vim.uv.fs_stat(resolved)
  if not source_stat then
    return resolved
  end

  local has_magick = vim.fn.executable("magick") == 1
  local has_convert = vim.fn.executable("convert") == 1
  if not has_magick and not has_convert then
    return resolved
  end

  local cache_dir = vim.fn.resolve(vim.fn.stdpath("cache") .. "/markdown-svg-preview")
  vim.fn.mkdir(cache_dir, "p")

  local png_path = vim.fn.resolve(cache_dir .. "/" .. vim.fn.sha256(resolved) .. ".png")
  local png_stat = vim.uv.fs_stat(png_path)
  local source_mtime = source_stat.mtime and source_stat.mtime.sec or 0
  local png_mtime = png_stat and png_stat.mtime and png_stat.mtime.sec or -1

  if not png_stat or png_mtime < source_mtime then
    local command = has_magick and { "magick", resolved, "png:" .. png_path } or { "convert", resolved, "png:" .. png_path }
    local result = vim.system(command, { text = true }):wait()
    if result.code ~= 0 or vim.fn.filereadable(png_path) ~= 1 then
      return resolved
    end
  end

  return png_path
end

require("image").setup({
  processor = "magick_cli",
  integrations = {
    markdown = {
      resolve_image_path = resolve_markdown_image_path,
    },
  },
})

require("diagram").setup({
  renderer_options = {
    mermaid = {
      scale = 2,
    },
  },
  integrations = {
    require("diagram.integrations.markdown"),
  },
})

vim.keymap.set("n", "<leader>dh", function()
  if vim.bo.filetype == "mermaid" then
    mermaid_integration.open_current_buffer_svg()
    return
  end
  require("diagram").show_diagram_hover()
end, { desc = "Show diagram hover" })
