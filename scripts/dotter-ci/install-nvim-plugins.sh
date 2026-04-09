#!/bin/bash
# Install Neovim plugins
# Usage: install-nvim-plugins.sh <deploy-dir>

set -e

DEPLOY_DIR="${1:-$(cat /tmp/dotter_deploy_dir 2>/dev/null)}"

if [ -z "$DEPLOY_DIR" ] || [ ! -d "$DEPLOY_DIR" ]; then
  echo "Error: Deploy directory not found"
  echo "Usage: install-nvim-plugins.sh <deploy-dir>"
  exit 1
fi

export HOME="$DEPLOY_DIR"

# Install tree-sitter CLI if needed
if ! command -v tree-sitter &> /dev/null; then
  npm install -g tree-sitter-cli
fi

# Install plugins with timeout
timeout 300 nvim --headless -c "lua vim.defer_fn(function()
  local timer = vim.uv.new_timer()
  timer:start(0, 3000, vim.schedule_wrap(function()
    local result = vim.system({'pgrep', '-f', 'git.*clone'}):wait()
    if result.code ~= 0 then
      timer:stop()
      timer:close()
      vim.cmd('qa!')
    end
  end))
end, 5000)" 2>&1 | tee /tmp/nvim-install.txt || true

echo "Plugin installation output:"
cat /tmp/nvim-install.txt
