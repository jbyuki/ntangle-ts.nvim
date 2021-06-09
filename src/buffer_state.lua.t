##ntangle-ts
@script_variables+=
local states = {}

@init_text_state+=
states[bufname] = vim.api.nvim_buf_get_lines(0, 0, -1, true)

@do_text_transformation+=
local state = states[bufname]

@delete_text_in_range
@insert_text_in_range

states[bufname] = state

@delete_text_in_range+=
if end_row == 0 then
  if start_row+1 <= #state then
    state[start_row+1] = state[start_row+1]:sub(1, start_col) .. state[start_row+1]:sub(start_col+end_col+1)
  end
else

  local beg = state[start_row+1]:sub(1, start_col)
  local rest = (state[start_row+end_row+1] or ""):sub(end_col+1)

  table.remove(state, start_row+end_row+1)

  for i=1,end_row-1 do
    table.remove(state, i+start_row+1)
  end
  state[start_row+1] = beg .. rest
end

@functions+=
local function get_line(buf, row)
  local line = vim.api.nvim_buf_get_lines(buf, row, row+1, false)
  if #line == 0 then
    return ""
  else
    return line[1]
  end
end

@insert_text_in_range+=
if new_end_row == 0 then
  local line = get_line(buf, start_row)
  state[start_row+1] = state[start_row+1]:sub(1, start_col) .. line:sub(start_col+1, start_col+new_end_col) .. state[start_row+1]:sub(start_col+1)
else
  for i=1,new_end_row-1 do
    local line = get_line(buf, start_row+i)
    table.insert(state, i+start_row+1, line)
  end

  local line = get_line(buf, start_row)
  local beg = (state[start_row+1] or ""):sub(1, start_col)
  local rest = (state[start_row+1] or ""):sub(start_col+1)
  state[start_row+1] = beg .. line:sub(start_col+1)

  local line = get_line(buf, start_row+new_end_row)
  table.insert(state, start_row+new_end_row+1, line:sub(1, new_end_col) .. rest)
end

@implement+=
function M.show_state()
  local bufname = string.lower(vim.api.nvim_buf_get_name(0))
  local state = states[bufname]

  for i, line in ipairs(state) do
    print(i, vim.inspect(line))
  end
end
