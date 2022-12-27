local builtin = require('telescope.builtin')

--- find project files
vim.keymap.set('n', '<leader>pf', builtin.find_files, {})

--- find git files
vim.keymap.set('n', '<C-p>', builtin.git_files, {})

--- find in files
vim.keymap.set('n', '<C-f>', function()
	builtin.grep_string({ search = vim.fn.input("Grep > ") })
end)

vim.keymap.set('n', 'gi', builtin.lsp_implementations, {})
