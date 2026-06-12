-- Recognize Salesforce extensions so proper LSPs activate
vim.filetype.add({
	extension = { cls = "apex", trigger = "apex", page = "visualforce", component = "visualforce", apex = "apex" },
})

-- Manage a Salesforce CLI terminal
local job_id = 0
vim.keymap.set("n", "<leader>sfterm", function()
	vim.cmd.vnew()
	vim.cmd.term()
	vim.cmd.wincmd("J")
	vim.api.nvim_win_set_height(0, 10)

	job_id = vim.bo.channel
end)

-- Send the standard Salesforce CLI deploy command
vim.keymap.set("n", "<leader>sfd", function()
	vim.fn.chansend(job_id, { "sf project deploy start\r\n" })
end)

-- Add keymaps to Which-Key
local wk = require("which-key")
local test_runner = require("salesforce.test_runner")
local file_manager = require("salesforce.file_manager")
local get_deploy_cmd = function(file_path)
	local deploy_cmd = "!sf project deploy start"
	if file_path == nil then
		return deploy_cmd
	end

	local class_name = file_path:match(".*/(.-)%.cls")
	if class_name == nil then
		return deploy_cmd
	end

	return deploy_cmd .. " --metadata ApexClass:" .. class_name
end
wk.register({
	d = {
		name = "Deploy to Salesforce",
		c = { file_manager.push_to_org, "Deploy This File Only" },
		p = { "<cmd>!sf project deploy start<cr>", "Deploy Project" },
		t = {
			name = "Deploy and Run Apex Tests",
			p = {
				function()
					vim.cmd("!sf project deploy start --concise --test-level RunLocalTests")
				end,
				"Deploy Project and Run All Tests",
			},
			c = {
				function()
					vim.cmd(get_deploy_cmd(vim.api.nvim_buf_get_name(0)))
					test_runner.execute_current_class()
				end,
				"Deploy and Run Current Test Class",
			},
			m = {
				function()
					vim.cmd(get_deploy_cmd(vim.api.nvim_buf_get_name(0)))
					test_runner.execute_current_method()
				end,
				"Deploy and Run Current Test Method",
			},
		},
	},
	t = {
		name = "Run Salesforce Apex Tests",
		p = { "<cmd>!sf apex run test --synchronous<cr>", "Run All Tests" },
		c = { test_runner.execute_current_class, "Run Current Test Class" },
		m = { test_runner.execute_current_method, "Run Current Test Method" },
	},
	o = {
		name = "Manage Salesforce Orgs",
		o = { "<cmd>!sf org open<cr>", "Open Default Org" },
		l = { "<cmd>!sf org list<cr>", "List Orgs" },
	},
}, { prefix = "<leader>sf" })

--[[
-- New Which-Key bindings
    wk.register({
      { "<leader>sfd",  group = "Deploy to Salesforce" },
      { "<leader>sfdc", file_manager.push_to_org,            desc = "Deploy This File Only" },
      { "<leader>sfdp", "<cmd>!sf project deploy start<cr>", desc = "Deploy Project" },
      { "<leader>sfdt", group = "Deploy and Run Apex Tests" },
      {
        "<leader>sfdtc",
        function()
          vim.cmd(get_deploy_cmd(vim.api.nvim_buf_get_name(0)))
          test_runner.execute_current_class()
        end,
        desc = "Deploy and Run Current Test Class",
      },
      {
        "<leader>sfdtm",
        function()
          vim.cmd(get_deploy_cmd(vim.api.nvim_buf_get_name(0)))
          test_runner.execute_current_method()
        end,
        desc = "Deploy and Run Current Test Method",
      },
      {
        "<leader>sfdtp",
        function()
          vim.cmd("!sf project deploy start")
          vim.cmd("!sf apex run test --synchronous")
        end,
        desc = "Deploy Project and Run All Tests",
      },
      { "<leader>sfo",  group = "Manage Salesforce Orgs" },
      { "<leader>sfol", "<cmd>!sf org list<cr>",                    desc = "List Orgs" },
      { "<leader>sfoo", "<cmd>!sf org open<cr>",                    desc = "Open Default Org" },
      { "<leader>sft",  group = "Run Salesforce Apex Tests" },
      { "<leader>sftc", test_runner.execute_current_class,          desc = "Run Current Test Class" },
      { "<leader>sftm", test_runner.execute_current_method,         desc = "Run Current Test Method" },
      { "<leader>sftp", "<cmd>!sf apex run test --synchronous<cr>", desc = "Run All Tests" },
    })
}
]]
