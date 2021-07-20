##ntangle-ts-next
@script_variables+=
local playground_text = ""
local playground_buf

@create_playground+=
local old_win = vim.api.nvim_get_current_win()
vim.cmd [[sp]]

playground_buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_set_current_buf(playground_buf)
vim.api.nvim_set_current_win(old_win)

@display_generated_into_playground+=
playground_text = ""
for _, line in ipairs(lines) do
  playground_text = playground_text .. line .. "\n"
end

local playground_lines = vim.split(playground_text, "\n")
vim.api.nvim_buf_set_lines(playground_buf, 0, -1, true, playground_lines)

@apply_changes_to_playground+=
for _, change in ipairs(changes) do
  @apply_change_on_playground_text
end

@apply_change_on_playground_text+=
local off, del, ins, ins_text = unpack(change)
ins_text = ins_text or ""
local s1 = playground_text:sub(1, off)
local s2 = playground_text:sub(off+del+1)
playground_text = s1 .. ins_text .. s2

@refresh_playground_text+=
local lines = vim.split(playground_text, "\n")
vim.api.nvim_buf_set_lines(playground_buf, 0, -1, true, lines)
