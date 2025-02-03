require("plugins")
vim.o.tabstop = 4 -- A TAB character looks like 4 spaces
vim.o.shiftwidth = 4 -- Number of spaces inserted when indenting
vim.o.number = true
vim.o.relativenumber = true

local harpoon = require("harpoon")
harpoon:setup()

vim.keymap.set("n", "<leader>a", function() harpoon:list():add() end)
vim.keymap.set("n", "<C-e>", function() harpoon.ui:toggle_quick_menu(harpoon:list()) end)

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  {'neovim/nvim-lspconfig'},             -- LSP configurations
  {'williamboman/mason.nvim'},           -- Installer for external tools
  {'williamboman/mason-lspconfig.nvim'}, -- mason extension for lspconfig
  {'hrsh7th/nvim-cmp'},                  -- Autocomplete engine
  {'hrsh7th/cmp-nvim-lsp'},              -- Completion source for LSP
  {'L3MON4D3/LuaSnip'},                  -- Snippet engine
  {'mfussenegger/nvim-dap'},               -- Debug Adapter Protocol (DAP)
  {'rcarriga/nvim-dap-ui'},                -- UI for debugging
  {'nvim-lua/plenary.nvim'},               -- Utility library
  {'nvim-telescope/telescope.nvim'},       -- Fuzzy finder
  {'nvim-treesitter/nvim-treesitter'},
  {'huggingface/llm.nvim'},
  {"olimorris/codecompanion.nvim"},
})


local lspconfig = require('lspconfig')
lspconfig.lua_ls.setup({})

local lsp_capabilities = require('cmp_nvim_lsp').default_capabilities()

require("mason").setup()
require("mason-lspconfig").setup {
    ensure_installed = { "lua_ls", "ts_ls", "eslint", "gopls", "marksman", "pylsp", "clangd", "hls" },
	handlers = {
		function(server)
			lspconfig[server].setup({
				capabilities = lsp_capabilities,
			})
		end,
		['ts_ls'] = function()
			lspconfig.ts_ls.setup({
				capabilities = lsp_capabilities,
				settings = {
					completions = {
						completeFunctionCalls = true
					}
				}
			})
		end,
		["hls"] = function()
			lspconfig.hls.setup({
				haskell = {
					hlintOn = true,
					formattingProvider = 'ormolu',
				}
			})
		end,
		["clangd"] = function()
			lspconfig.clangd.setup({
				filestypes = { "c", "cpp", "metal", "objc", "objcpp" }
			})
		end,
	}
}

-- Recommended by LspInfo for Typescript
lspconfig.eslint.setup({
	on_attach = function(client, bufnr)
		vim.api.nvim_create_autocmd("BufWritePre", {
			buffer = bufnr,
			command = "EslintFixAll",
		})
	end,
})

vim.api.nvim_create_autocmd({"BufNewFile", "BufRead"}, {
	pattern = "*.metal",
	callback = function()
		vim.bo.filetype = "cpp"
	end
})

vim.api.nvim_create_autocmd("BufWritePre", {
	pattern = "*.hs",
	callback = function()
		vim.lsp.buf.format()
	end,
})


local llm = require('llm')

llm.setup({
  api_token = nil, -- cf Install paragraph
  model = "qwen2.5-coder", -- the model ID, behavior depends on backend
  backend = "ollama", -- backend ID, "huggingface" | "ollama" | "openai" | "tgi"
  url = "http://localhost:11434", -- the http url of the backend
  tokens_to_clear = { "<|endoftext|>" }, -- tokens to remove from the model's output
  debug = true,
  system_prompt = [[
        You are an AI code assistant. 
        Only return function implementations. 
        Do NOT use markdown formatting. 
        Do NOT include triple backticks (` ``` `).
        Return only valid, executable code.
    ]],
  -- parameters that are added to the request body, values are arbitrary, you can set any field:value pair here it will be passed as is to the backend
  request_body = {
	  parameters = {
		  max_new_tokens = 1000,
		  temperature = 0.2,
		  top_p = 0.95,
	  },
  },
  debounce_ms = 150,
  accept_keymap = "<Tab>",
  dismiss_keymap = "<S-Tab>",
  tls_skip_verify_insecure = false,
  -- llm-ls configuration, cf llm-ls section
  lsp = {
	  bin_path = nil,
	  host = nil,
	  port = nil,
	  cmd_env = nil, -- or { LLM_LOG_LEVEL = "DEBUG" } to set the log level of llm-ls
	  version = "0.5.3",
  },
  tokenizer = nil, -- cf Tokenizer paragraph
  context_window = 1024, -- max number of tokens for the context window
  enable_suggestions_on_startup = true,
  enable_suggestions_on_files = "*", -- pattern matching syntax to enable suggestions on specific files, either a string or a list of strings
  disable_url_path_completion = false, -- cf Backend
})

vim.api.nvim_create_user_command("QwenAsk", function(opts)
	local query = opts.args
	local prompt = [[
        You are an AI code assistant. 
        Only return function implementations. 
        Do NOT use markdown formatting. 
        Do NOT include triple backticks (` ``` `).
        Return only valid, executable code.
    ]]
	local command = string.format(
	'curl -X POST http://localhost:11434/api/generate -d \'{"model": "qwen2.5-coder", "prompt": "%s: %s", "max_tokens": 500, "temperature": 0.3, "stream": false}}\'',
	prompt,
	query
	)
	local handle = io.popen(command)
	local result = handle:read("*a")
	handle:close()

	-- Extract the "response" field from JSON
	local response = result:match('"response":"(.-)"')
	print(response or "No response")
end, { nargs = 1 })

local cmp = require'cmp'
cmp.setup({
	mapping = cmp.mapping.preset.insert({
		['<C-Space>'] = cmp.mapping.complete(),
		['<CR>'] = cmp.mapping.confirm({ select = true }),
	}),
	sources = cmp.config.sources({
		{ name = 'nvim_lsp' },  -- Use LSP for AI completions
		{ name = 'luasnip' },   -- Enable snippets
	}),
})

-- My Keybindings
vim.g.mapleader = " "
vim.keymap.set("n", "<leader>w", ":w<CR>", { desc = "Save file" }) -- Save file
vim.keymap.set("n", "<leader>q", ":q<CR>", { desc = "Quit file" }) -- Quit file
vim.keymap.set("n", "<leader>x", ":x<CR>", { desc = "Save and quit" }) -- Save & Quit

vim.keymap.set("n", "<leader>bn", ":bnext<CR>", { desc = "Next buffer" })  -- Next buffer
vim.keymap.set("n", "<leader>bp", ":bprev<CR>", { desc = "Previous buffer" })  -- Previous buffer
vim.keymap.set("n", "<leader>bd", ":bd<CR>", { desc = "Close buffer" })  -- Close buffer

vim.keymap.set("n", "<leader>h", "<C-w>h", { desc = "Move left window" })
vim.keymap.set("n", "<leader>j", "<C-w>j", { desc = "Move down window" })
vim.keymap.set("n", "<leader>k", "<C-w>k", { desc = "Move up window" })
vim.keymap.set("n", "<leader>l", "<C-w>l", { desc = "Move right window" })
vim.keymap.set("n", "<leader>t", "<C-w>w", { desc = "Move next window" })

vim.keymap.set("n", "<leader>ff", ":Telescope find_files<CR>", { desc = "Find files" })
vim.keymap.set("n", "<leader>fg", ":Telescope live_grep<CR>", { desc = "Live grep" })

vim.keymap.set("n", "<leader>s", function()
	vim.diagnostic.open_float()
end, { desc = "Show more detail" })
vim.keymap.set("n", "<leader>i", function()
	vim.lsp.buf.hover()
end, { desc = "Info on variable" })

vim.keymap.set("n", "<leader>o", ":Ex<CR>", { desc = "Open file explorer" })


require("codecompanion").setup({
	backend = "ollama",  -- Use Ollama as the AI backend
	model = "qwen2.5-coder:32b",
	temperature = 0.2,  -- Lower for more deterministic responses
	max_tokens = 800,
	system_prompt = "You are a coding assistant. Respond only with valid, executable code. No explanations.",
	inline = true,  -- Show inline AI suggestions
	keymaps = {
		accept = "<Tab>",  -- Accept AI suggestions
		dismiss = "<C-e>" -- Dismiss AI suggestions
	}
})

vim.keymap.set("n", "<leader>cc", function()
	require("codecompanion").complete()
end, { desc = "Trigger AI code completion" })

vim.keymap.set("v", "<leader>ce", function()
	require("codecompanion").explain()
end, { desc = "Explain selected code with AI" })

