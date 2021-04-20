##../do_test
@*=
vim.api.nvim_command("edit C:/Users/I354324/fakeroot/code/nvimplugins/ntangle-ts.nvim/src/test.lua.t")
vim.api.nvim_buf_set_lines(0, 0, -1, true, {})


vim.api.nvim_buf_set_lines(0, 0, -1, true, {
  "@*=",
  "function test()",
  "  @print",
  "  if false then",
  "  @else_case",
  "end",
  "@else_case+=",
  "else",
  "  local a = 0",
  "  print(a)",
  "end",
})

require"ntangle-ts".attach()

vim.api.nvim_buf_set_lines(0, 0, 0, true, {
  "##test",
})

vim.api.nvim_buf_set_lines(0, 0, 1, true, { })

vim.api.nvim_command("bw!")
