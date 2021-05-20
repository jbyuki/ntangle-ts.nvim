##ntangle-ts
@implement+=
function M.go_up()
  @retrieve_buffer_variables
  @retrieve_containing_section
  @search_all_references
  @fill_quicklist_with_reference_locations
  @jump_to_first_reference_location
end

@retrieve_buffer_variables+=
local bufname = string.lower(vim.api.nvim_buf_get_name(buf))

local buf_asm = buf_vars[bufname].buf_asm
local start_buf = buf_vars[bufname].start_buf
local end_buf = buf_vars[bufname].end_buf

local parts_ll = asm_namespaces[buf_asm].parts_ll

@retrieve_containing_section+=
local lnum, _ = unpack(vim.api.nvim_win_get_cursor(0))

local search = start_buf
for _=1,lnum do
  search = search.next
end

local section_name
while search do
  if search.data.linetype == LineType.SECTION then
    section_name = search.data.str
    break
  end
  search = search.prev
end

if not section_name then
  return
end

@search_all_references+=
local references = {}
for part in linkedlist.iter(parts_ll) do
  local start_part = part.start_buf
  local end_part = part.end_buf
  @find_reference_in_part
end

@find_reference_in_part+=
local it = start_part.next
local part_lnum = 1
while it and it ~= end_part do
  if it.data.linetype == LineType.REFERENCE and it.data.str == section_name then
    @add_location_to_reference_list
  end
  part_lnum = part_lnum + 1
  it = it.next
end

@add_location_to_reference_list+=
table.insert(references, {
  filename = part.name,
  lnum = part_lnum,
})

@fill_quicklist_with_reference_locations+=
vim.fn.setqflist(references)

@jump_to_first_reference_location+=
if #references == 0 then
  print("No reference found.")
else
  if references[1].filename ~= buf then
    vim.api.nvim_command("e " .. references[1].filename)
  end
  vim.api.nvim_win_set_cursor(0, {references[1].lnum, 0})
end
