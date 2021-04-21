##ntangle-ts
@send_on_bytes+=
local lnum = 1
local lrow = 1
local it = tangled_ll.head

local source_len = 0

while it do
  if it.data.linetype == LineType.TANGLED then
    if it.data.remove then
      @send_delete_on_byte
      @delete_it_from_tangled
    elseif it.data.insert then
      @send_insert_on_byte
      @add_line_to_tangled
      it.data.insert = nil
      lrow = lrow + 1
      it = it.next
    else
      @add_line_to_tangled
      lrow = lrow + 1
      it = it.next
    end
  else
      it = it.next
  end
end

@delete_it_from_tangled+=
local tmp = it
it = it.next
linkedlist.remove(tangled_ll, tmp)

@send_delete_on_byte+=
local start_byte = source_len
local start_col = 0
local start_row = lrow-1
local old_row = 1
local new_row = 0
local old_byte = string.len(it.data.line) + 1
local new_byte = 0
local old_end_col = 0
local new_end_col = 0

trees[buf]:edit(start_byte,start_byte+old_byte,start_byte+new_byte,
  start_row, start_col,
  start_row+old_row, old_end_col,
  start_row+new_row, new_end_col)

@add_line_to_tangled+=
if source_len == 0 then
  source_len = source_len + string.len(it.data.line)
else
  source_len = source_len + string.len(it.data.line) + 1
end

@send_insert_on_byte+=
local start_byte = source_len
local start_col = 0
local start_row = lrow-1
local old_row = 0
local new_row = 1
local old_byte = 0
local new_byte = string.len(it.data.line) + 1
local old_end_col = 0
local new_end_col = 0

trees[buf]:edit(start_byte,start_byte+old_byte,start_byte+new_byte,
  start_row, start_col,
  start_row+old_row, old_end_col,
  start_row+new_row, new_end_col)
