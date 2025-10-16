return {
	"nvimtools/none-ls.nvim",
	dependencies = { "nvimtools/none-ls-extras.nvim" },
	config = function()
		local null_ls = require("null-ls")

		null_ls.setup({
			sources = {
				null_ls.builtins.formatting.stylua,
				null_ls.builtins.formatting.prettier.with({
					extra_filetypes = { "apex" },
					extra_args = {
						"--plugin=prettier-plugin-apex",
					},
				}),
				require("none-ls.diagnostics.eslint"), -- requires none-ls-extras.nvim
        null_ls.builtins.formatting.xmllint,
			},
		})

    local helpers = require("null-ls.helpers")
		local sf_code_analyzer = {
      name = "sf code-analyzer",
			method = null_ls.methods.DIAGNOSTICS,
			filetypes = { "apex" },
			-- null_ls.generator creates an async source
			-- that spawns the command with the given arguments and options
			generator = null_ls.generator({
				command = "sf",
				args = { "code-analyzer", "run", "--workspace", "$FILENAME" },
				format = "line",
				check_exit_code = function(code, stderr)
					local success = code <= 1

					if not success then
						-- can be noisy for things that run often (e.g. diagnostics), but can
						-- be useful for things that run on demand (e.g. formatting)
						print(stderr)
					end

					return success
				end,
				-- use helpers to parse the output from string matchers,
				-- or parse it manually with a function
				on_output = function(output)
          local parse_diagnostics = helpers.diagnostics.from_patterns({
				  	{
				  		pattern = [[^(?:[\s:]+|\S+)(?:[\s:]+(?:\S+|\s+))(?:[\s:]+(?:\S+|\s+)(?=\s|$))(?:[\s:]+(?:\S+|\s+)){6}(.*)$]],
					  	groups = { "output_row", "severity", "severity_detail", "engine", "rule", "path", "row", "col", "message" },
					  },

				  })
          print(parse_diagnostics(output))
          return parse_diagnostics
        end,
			}),
		}

		-- null_ls.register(sf_code_analyzer)
	end,
}
