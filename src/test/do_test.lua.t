##../do_test
@*=
os.remove("tangle/test.test.lua.t")
os.remove("tangle/test2.test.lua.t")

vim.api.nvim_command("edit test.lua.t")
vim.api.nvim_buf_set_lines(0, 0, -1, true, {
  "##test",
  "@*=",
  "@hello",
})

require"ntangle-ts".attach()

vim.api.nvim_command("edit test2.lua.t")


vim.api.nvim_buf_set_lines(0, 0, -1, true, {
  "##test",
  "@hello+=",
  "print(a)",
})
require"ntangle-ts".attach()

vim.api.nvim_buf_set_lines(0, 0, -1, true, {})

vim.api.nvim_command("bw!")

vim.api.nvim_command("edit! test.lua.t")
vim.api.nvim_command("bw!")
