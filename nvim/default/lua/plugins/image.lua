vim.pack.add({
  "https://github.com/3rd/image.nvim",
  "https://github.com/3rd/diagram.nvim",
})

local mermaid_integration = require("config.diagram_mermaid")

local function convert_svg_to_png(path)
  local has_sips = vim.fn.executable("sips") == 1
  local has_rsvg = vim.fn.executable("rsvg-convert") == 1
  local has_magick = vim.fn.executable("magick") == 1
  local has_convert = vim.fn.executable("convert") == 1
  if not has_sips and not has_rsvg and not has_magick and not has_convert then
    return path
  end

  local source_stat = vim.uv.fs_stat(path)
  if not source_stat then
    return path
  end

  local cache_dir = vim.fn.resolve(vim.fn.stdpath("cache") .. "/image-nvim-svg-preview")
  vim.fn.mkdir(cache_dir, "p")

  local png_path = vim.fn.resolve(cache_dir .. "/" .. vim.fn.sha256(path) .. ".png")
  local png_stat = vim.uv.fs_stat(png_path)
  local source_mtime = source_stat.mtime and source_stat.mtime.sec or 0
  local png_mtime = png_stat and png_stat.mtime and png_stat.mtime.sec or -1

  if not png_stat or png_mtime < source_mtime then
    local commands = {}
    if has_sips then
      table.insert(commands, { "sips", "-s", "format", "png", path, "--out", png_path })
    end
    if has_rsvg then
      table.insert(commands, { "rsvg-convert", "-o", png_path, path })
    end
    if has_magick then
      table.insert(commands, { "magick", path, "png:" .. png_path })
    elseif has_convert then
      table.insert(commands, { "convert", path, "png:" .. png_path })
    end

    local converted = false
    for _, command in ipairs(commands) do
      local result = vim.system(command, { text = true }):wait()
      if result.code == 0 and vim.fn.filereadable(png_path) == 1 then
        converted = true
        break
      end
    end

    if not converted then
      return path
    end
  end

  return png_path
end

local image = require("image")

image.setup({
  processor = "magick_cli",
})

local image_from_file = image.from_file
image.from_file = function(path, options)
  if type(path) == "string" and path:lower():match("%.svg$") then
    path = convert_svg_to_png(path)
  end
  return image_from_file(path, options)
end

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
