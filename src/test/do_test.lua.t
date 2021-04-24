##../do_test
@*=
vim.api.nvim_command("edit test.cpp.t")
vim.api.nvim_buf_set_lines(0, 0, -1, true, {
  "##test",
  "@test.cpp=",
  "#include <iostream>",
  "auto main() -> int",
  "{",
  " return 0;",
  "}",
})

require"ntangle-ts".attach()

vim.api.nvim_buf_set_lines(0, -1, -1, true, {
  "@test.h=",
})

vim.api.nvim_buf_set_lines(0, -1, -1, true, {
  "#pragma once",
  "auto f() -> int;",
})

vim.api.nvim_command("bw!")
