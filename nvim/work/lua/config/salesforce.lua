-- Recognize Salesforce extensions so proper LSPs activate
vim.filetype.add({
	extension = { cls = "apex", trigger = "apex", page = "visualforce", component = "visualforce", apex = "apex" },
})
