##../do_test
@*=
vim.api.nvim_command("edit test2.lua.t")
vim.api.nvim_buf_set_lines(0, -1, -1, true, {
  "@hello"
})
vim.api.nvim_command("bw!")
