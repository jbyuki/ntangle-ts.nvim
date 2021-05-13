##../do_test
@*=
vim.api.nvim_command("edit test2.lua.t")
vim.api.nvim_buf_set_lines(0, 0, -1, true, {
  "@*=",
  "@includes",
  "@global_variables",
  "hello",
  "",
  "@global_variables+=",
  "",
})

vim.api.nvim_buf_set_lines(0, 6, 7, true, {})

require"ntangle-ts".print_tangled()

vim.api.nvim_command("bw!")
