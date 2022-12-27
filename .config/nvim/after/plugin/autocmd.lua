local autocmd = vim.api.nvim_create_autocmd
autocmd({"BufNewFile", "BufRead"}, {
    pattern = "*.php",
    callback = function()
        vim.opt.syntax = "php"
    end,
})

