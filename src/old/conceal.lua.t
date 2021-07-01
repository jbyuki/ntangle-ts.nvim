##ntangle-ts
@enable_conceal_reference_names+=
vim.fn.matchadd("Conceal", [[\(^\s*@.*\)\@<=_]], 10, -1, { conceal = ' '})
-- vim.fn.matchadd("Conceal", [[^\s*\zs@\ze.*\([^=]\)]], 10, -1, { conceal = ''})
-- vim.fn.matchadd("Conceal", [[^\s*\zs@\ze.*=]], 10, -1, { conceal = ''})
vim.api.nvim_command([[setlocal conceallevel=2]])
vim.api.nvim_command([[setlocal concealcursor=nc]])
