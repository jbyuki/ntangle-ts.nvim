##ntangle-ts
@send_on_bytes+=
for name, root in pairs(root_set) do
  local parser = root.parser
  local start_file = root.start_file
  local end_file = root.end_file
  local tree = root.tree

  local it = start_file
  local lrow = 1
  local source_len = 0

  while it ~= end_file do
    if it.data.linetype == LineType.TANGLED then
      if it.data.remove then
        if not it.data.insert then
          @send_delete_on_byte
        end
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

if tree then
  tree:edit(start_byte,start_byte+old_byte,start_byte+new_byte,
    start_row, start_col,
    start_row+old_row, old_end_col,
    start_row+new_row, new_end_col)
  @send_to_cbs
end

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

if tree then
  tree:edit(start_byte,start_byte+old_byte,start_byte+new_byte,
    start_row, start_col,
    start_row+old_row, old_end_col,
    start_row+new_row, new_end_col)
  @send_to_cbs
end

@reset_all_insert+=
for name, root in pairs(root_set) do
  local start_file = root.start_file
  local end_file = root.end_file

  local it = start_file

  while it ~= end_file do
    it.data.insert = nil
    it = it.next
  end
end
