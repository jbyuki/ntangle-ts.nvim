##ntangle-ts-next
@script_variables+=
local internal_buf

@create_internal_state+=
local old_win = vim.api.nvim_get_current_win()
vim.cmd [[sp]]

internal_buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_set_current_buf(internal_buf)
vim.api.nvim_set_current_win(old_win)

@display_internal_state+=
local lines = {}
local single_line = {}
for data in linkedlist.iter(content) do
  if data.type == UNTANGLED.CHAR then
    table.insert(single_line, "CHAR " .. vim.inspect(data.sym))
  elseif data.type == UNTANGLED.SENTINEL then
    if #single_line > 0 then
      table.insert(lines, table.concat(single_line, " "))
      single_line = {}
    end

    table.insert(lines, "SENTINEL " .. M.get_linetype(data.parsed.linetype))
  end
end

if single_line ~= "" then
  table.insert(lines, table.concat(single_line, " "))
end

vim.api.nvim_buf_set_lines(internal_buf, 0, -1, true, lines)

@implement+=
function M.get_linetype(t)
  if t == LineType.EMPTY then return "EMPTY"
  elseif t == LineType.SECTION then return "SECTION"
  elseif t == LineType.REFERENCE then return "REFERENCE"
  elseif t == LineType.TEXT then return "TEXT"
  else return "UNKNOWN" end
end
