##../do_test
@*=
vim.api.nvim_command("edit test.lua.t")
vim.api.nvim_buf_set_lines(0, 0, -1, true, {})


vim.api.nvim_buf_set_lines(0, 0, -1, true, {
  "@*=",
  "print(a)",
})
require"ntangle-ts".attach()

vim.api.nvim_buf_set_lines(0, 1, 1, true, {
  "local a = 0",
})

vim.api.nvim_command("bw!")
