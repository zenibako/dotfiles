return {
  "David-Kunz/jester",
  dependencies = {
    "rcarriga/nvim-dap-ui",
    "mfussenegger/nvim-dap",
    "nvim-neotest/nvim-nio",
    {
      "mxsdev/nvim-dap-vscode-js",
      opt = true,
      run = "npm install --legacy-peer-deps && npx gulp vsDebugServerBundle && mv dist out",
    },
  },
  config = function()
    local jester = require("jester")
    local dap = require("dap")

    require("dap-vscode-js").setup({
      -- node_path = "node", -- Path of node executable. Defaults to $NODE_PATH, and then "node"
      -- debugger_path = "(runtimedir)/site/pack/packer/opt/vscode-js-debug", -- Path to vscode-js-debug installation.
      -- debugger_cmd = { "js-debug-adapter" }, -- Command to use to launch the debug server. Takes precedence over `node_path` and `debugger_path`.
      adapters = { "pwa-node", "pwa-chrome", "pwa-msedge", "node-terminal", "pwa-extensionHost" }, -- which adapters to register in nvim-dap
      -- log_file_path = "(stdpath cache)/dap_vscode_js.log" -- Path for file logging
      -- log_file_level = false -- Logging level for output to file. Set to false to disable file logging.
      -- log_console_level = vim.log.levels.ERROR -- Logging level for output to console. Set to false to disable console output.
    })

    for _, language in ipairs({ "typescript", "javascript" }) do
      dap.configurations[language] = {
        type = "pwa-node",
        request = "launch",
        name = "Debug Jest Tests",
        -- trace = true, -- include debugger info
        program = "${workspaceFolder}/node_modules/.bin/sf-lwc-jest",
        runtimeExecutable = "node",
        args = {
          "--",
          "--runInBand",
        },
        cwd = "${workspaceFolder}",
        console = "integratedTerminal",
        internalConsoleOptions = "neverOpen",
        disableOptimisticBPs = true,
        windows = {
          program = "${workspaceFolder}/node_modules/@salesforce/sf-lwc-jest/bin/sf-lwc-jest",
        },
      }
    end

    local dapUi = require("dapui")
    dapUi.setup()
    jester.setup({
      dap = dap.configurations["typescript"],
      path_to_jest_run = "npm run test:unit --",
    })

    local wk = require("which-key")
    wk.register({
      { "<leader>jd",  group = "Debug Jest Tests" },
      { "<leader>jdc", jester.debug,              desc = "Debug Current Method" },
      { "<leader>jdf", jester.debug_file,         desc = "Debug Current File" },
      { "<leader>jdl", jester.debug_last,         desc = "Debug Last Test(s)" },
      { "<leader>jr",  group = "Run Jest Tests" },
      { "<leader>jrc", jester.run,                desc = "Run Current Method" },
      { "<leader>jrf", jester.run_file,           desc = "Run Current File" },
      { "<leader>jrl", jester.run_last,           desc = "Run Last Test(s)" },
    })
  end,
}
