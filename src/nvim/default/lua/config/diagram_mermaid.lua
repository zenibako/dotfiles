local M = {}

function M.open_current_buffer_svg()
  local source = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  if vim.trim(source) == "" then
    vim.notify("No Mermaid diagram found in buffer", vim.log.levels.INFO)
    return
  end

  if vim.fn.executable("mmdc") ~= 1 then
    vim.notify("mmdc not found in PATH. Please install mermaid-cli to preview Mermaid diagrams.", vim.log.levels.ERROR)
    return
  end

  local cache_dir = vim.fn.resolve(vim.fn.stdpath("cache") .. "/diagram-cache/mermaid")
  vim.fn.mkdir(cache_dir, "p")

  local svg_path = vim.fn.resolve(cache_dir .. "/" .. vim.fn.sha256("mermaid-svg:" .. source) .. ".svg")
  local tmpsource = vim.fn.tempname()
  vim.fn.writefile(vim.split(source, "\n"), tmpsource)

  local result = vim.system({ "mmdc", "-i", tmpsource, "-o", svg_path }, { text = true }):wait()
  vim.fn.delete(tmpsource)

  if result.code ~= 0 or vim.fn.filereadable(svg_path) ~= 1 then
    local stderr = (result.stderr or ""):gsub("^%s+", ""):gsub("%s+$", "")
    vim.notify("Failed to render Mermaid SVG" .. (stderr ~= "" and ":\n" .. stderr or ""), vim.log.levels.ERROR)
    return
  end

  vim.ui.open(svg_path)
end

return M
