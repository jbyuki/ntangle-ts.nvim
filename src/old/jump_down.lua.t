##ntangle-ts
@implement+=
function M.go_down()
  @retrieve_buffer_variables
  @retrieve_reference_name
  @search_all_sections
  @fill_quicklist_with_reference_locations
  @jump_to_first_reference_location
end

@retrieve_reference_name+=
local lnum, _ = unpack(vim.api.nvim_win_get_cursor(0))

local search = start_buf
for _=1,lnum do
  search = search.next
end

if search.data.linetype ~= LineType.REFERENCE then
  print("No reference under cursor.")
  return
end

local reference_name = search.data.str

@search_all_sections+=
local references = {}
for part in linkedlist.iter(parts_ll) do
  local start_part = part.start_buf
  local end_part = part.end_buf
  @find_section_in_part
end

@find_section_in_part+=
local it = start_part.next
local part_lnum = 1
while it and it ~= end_part do
  if it.data.linetype == LineType.SECTION and it.data.str == reference_name then
    @add_location_to_reference_list
  end
  part_lnum = part_lnum + 1
  it = it.next
end
