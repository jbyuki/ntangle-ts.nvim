##ntangle-ts
@enable_conceal_reference_names+=
vim.fn.matchadd("Conceal", [[\(^\s*@.*\)\@<=_]], 10, -1, { conceal = ' '})
-- vim.fn.matchadd("Conceal", [[^\s*\zs@\ze.*\([^=]\)]], 10, -1, { conceal = ''})
-- vim.fn.matchadd("Conceal", [[^\s*\zs@\ze.*=]], 10, -1, { conceal = ''})