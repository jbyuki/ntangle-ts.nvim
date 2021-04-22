##ntangle-ts
@check_if_inserted_line_is_assembly+=
elseif i == 0 and string.match(line, "^##%S+$") then

  @get_assembly_name
  @construct_assembly_path
  @create_assembly_line
  @append_assembly_to_untangled
  @if_has_namespace_delete_tangled
  @retrieve_new_namespace
  @place_sentinel_in_new_namespace
  @transfer_untangled_to_new_namespace
  @generate_tangled_new_namespace_insert

  @save_new_buffer_variables


@get_assembly_name+=
local name = string.match(line, "^##(%S*)%s*$")

@construct_assembly_path+=
local fn = vim.api.nvim_buf_get_name(buf)
fn = vim.fn.fnamemodify(fn, ":p")
local parendir = vim.fn.fnamemodify(fn, ":p:h")
local assembly_parendir = vim.fn.fnamemodify(name, ":h")
local assembly_tail = vim.fn.fnamemodify(name, ":t")
local part_tail = vim.fn.fnamemodify(fn, ":t")
local link_name = parendir .. "/" .. assembly_parendir .. "/tangle/" .. assembly_tail .. "." .. part_tail
local path = vim.fn.fnamemodify(link_name, ":h")

@buffer_variables+=
local buf_asm

@script_variables+=
local asm_namespaces = {}

@buffer_variables+=
local untangled_ll
local sections_ll
local tangled_ll
local root_set
local parts_ll

@setup_initial_namespace_to_buffer+=
asm_namespaces[buf] = {
  untangled_ll = {},
  tangled_ll = {},
  sections_ll = {},
  root_set = {},
  parts_ll = {},
}

untangled_ll = asm_namespaces[buf].untangled_ll
sections_ll = asm_namespaces[buf].sections_ll
tangled_ll = asm_namespaces[buf].tangled_ll
root_set = asm_namespaces[buf].root_set
parts_ll = asm_namespaces[buf].parts_ll

@create_untangled_start_end_sentinel

@if_has_namespace_delete_tangled+=
if buf_asm then
  @delete_tangled_line_one_by_one
  @delete_part_in_parts
end

@buffer_variables+=
local start_buf, end_buf

@line_types+=
BUF_DELIM = 7,

@print_linetypes+=
elseif linetype == LineType.BUF_DELIM then
  return "BUFDELIM"

@create_untangled_start_end_sentinel+=
start_buf = linkedlist.push_back(untangled_ll, {
  linetype = LineType.BUF_DELIM,
  buf = buf,
  str = "START " .. buf,
})

end_buf = linkedlist.push_back(untangled_ll, {
  linetype = LineType.BUF_DELIM,
  buf = buf,
  str = "END " .. buf,
})

linkedlist.push_back(parts_ll, {
  start_buf = start_buf,
  end_buf = end_buf,
  name = vim.api.nvim_buf_get_name(buf),
})

@delete_tangled_line_one_by_one+=
local delete_this = start_buf.next
while delete_this ~= end_buf do
  local cur_delete = delete_this
  if not cur_delete then break end
  delete_this = delete_this.next

  @check_if_deleted_line_is_section_without_delete_untangled
  @check_if_deleted_line_is_reference
  @otherwise_deleted_line_is_text
end

@check_if_deleted_line_is_section_without_delete_untangled+=
if cur_delete.data.linetype == LineType.SECTION then
  local insert_after = cur_delete
  @remove_sentinel_or_bisentinel
  @remove_section_from_sections

@retrieve_new_namespace+=
local old_untangled_ll = untangled_ll

local check_links = false
if not asm_namespaces[name] then
  @create_new_namespace
  check_links = true
end

untangled_ll = asm_namespaces[name].untangled_ll
sections_ll = asm_namespaces[name].sections_ll
tangled_ll = asm_namespaces[name].tangled_ll
root_set = asm_namespaces[name].root_set
parts_ll = asm_namespaces[name].parts_ll
buf_asm = name

if type(name) ~= "number" and check_links then
  @check_if_there_are_links
  @read_all_links_except_current
end

@create_new_namespace+=
asm_namespaces[name] = {
  untangled_ll = {},
  tangled_ll = {},
  sections_ll = {},
  root_set = {},
  parts_ll = {},
}

@check_if_there_are_links+=
path = vim.fn.fnamemodify(path, ":p")
local parts = vim.split(vim.fn.glob(path .. assembly_tail .. ".*.t"), "\n")
link_name = vim.fn.fnamemodify(link_name, ":p")

@read_all_links_except_current+=
for _, part in ipairs(parts) do
	if link_name ~= part then
		@read_link_from_link_file
    if origin_path then
      @append_lines_from_part_file
    end
	end
end

@read_link_from_link_file+=
local f = io.open(part, "r")
local origin_path
if f then
  origin_path = f:read("*line")
  f:close()
end

@append_lines_from_part_file+=
local f = io.open(origin_path, "r")
if f then
  @create_start_and_end_sentinel_for_part
  @save_buf_vars_for_parts
	local lnum = 1
  local insert_after = start_buf
	while true do
		local line = f:read("*line")
		if not line then break end
    @check_if_inserted_line_is_section
    @check_if_inserted_line_is_reference
    @if_assembly_only_add_it_to_untangled
    @otherwise_inserted_line_is_text
		lnum = lnum + 1
	end
	f:close()
end

@if_assembly_only_add_it_to_untangled+=
elseif lnum == 1 and string.match(line, "^##%S+$") then
  @get_assembly_name
  @create_assembly_line
  @append_assembly_to_untangled

@create_start_and_end_sentinel_for_part+=
local start_buf = linkedlist.push_back(untangled_ll, {
  linetype = LineType.BUF_DELIM,
  str = "START " .. origin_path,
})

local end_buf = linkedlist.push_back(untangled_ll, {
  linetype = LineType.BUF_DELIM,
  str = "END " .. origin_path,
})

linkedlist.push_back(parts_ll, {
  start_buf = start_buf,
  end_buf = end_buf,
  name = origin_path,
})

@delete_part_in_parts+=
local it = parts_ll.head
local cur_name = vim.api.nvim_buf_get_name(0)
while it do
  if it.data.name == buf_name then
    linkedlist.remove(parts_ll, it)
    break
  end
  it = it.next
end

@place_sentinel_in_new_namespace+=
local part_after = parts_ll.head
local cur_name = vim.api.nvim_buf_get_name(0)
while part_after do
  if part_after.data.name > cur_name then
    break
  end
  part_after = part_after.next
end

local new_start_buf, new_end_buf
if not part_after then
  @push_part_sentinel_at_end
else
  @insert_part_sentinel_in_between
end

@push_part_sentinel_at_end+=
new_start_buf = linkedlist.push_back(untangled_ll, {
  linetype = LineType.BUF_DELIM,
  buf = buf,
  str = "START " .. bufname,
})

new_end_buf = linkedlist.push_back(untangled_ll, {
  linetype = LineType.BUF_DELIM,
  buf = buf,
  str = "END " .. bufname,
})

linkedlist.push_back(parts_ll, {
  start_buf = start_buf,
  end_buf = end_buf,
  name = vim.api.nvim_buf_get_name(buf),
})

@insert_part_sentinel_in_between+=
local end_buf_after = part_after.data.start_buf

new_start_buf = linkedlist.insert_before(untangled_ll, end_buf_after, {
  linetype = LineType.BUF_DELIM,
  buf = buf,
  str = "START " .. buf,
})


new_end_buf = linkedlist.insert_after(untangled_ll, new_start_buf, {
  linetype = LineType.BUF_DELIM,
  buf = buf,
  str = "END " .. buf,
})

linkedlist.insert_before(parts_ll, part_after, {
  start_buf = start_buf,
  end_buf = end_buf,
  name = cur_name
})

@transfer_untangled_to_new_namespace+=
local transfer_this = start_buf.next
local dest = new_start_buf
while transfer_this ~= end_buf do
  dest = linkedlist.insert_after(untangled_ll, dest, transfer_this.data)
  local delete_this = transfer_this
  transfer_this = transfer_this.next
  linkedlist.remove(old_untangled_ll, delete_this)
end

linkedlist.remove(old_untangled_ll, start_buf)
linkedlist.remove(old_untangled_ll, end_buf)
old_untangled_ll = nil
start_buf = new_start_buf
end_buf = new_end_buf

insert_after = start_buf.next

@generate_tangled_new_namespace_insert+=
do
  local it = start_buf.next.next
  while it ~= end_buf do
    local insert_after = it.prev
    if it.data.linetype == LineType.ASSEMBLY then
    @check_if_section_insert_back
    @check_if_reference_insert_back
    @otherwise_text_insert_back
    it = it.next
  end
end

@check_if_section_insert_back+=
elseif it.data.linetype == LineType.SECTION then
  local l = it.data
  local insert_after = it
  local op = l.op
  local name = l.str
  @insert_entry_to_sections
  @find_preceding_section_for_operator
  @if_none_find_all_references
  @insert_sentinel_for_section

  @if_root_section_add_bisentinels

@line_types+=
ASSEMBLY = 6,

@print_linetypes+=
elseif linetype == LineType.ASSEMBLY then return "ASSEMBLY"

@create_assembly_line+=
local l = {
  linetype = LineType.ASSEMBLY,
  str = name,
}

@append_assembly_to_untangled+=
insert_after = linkedlist.insert_after(untangled_ll, start_buf, l)

@check_if_deleted_line_is_assembly+=
elseif cur_delete == start_buf.next and cur_delete.data.linetype == LineType.ASSEMBLY then
  @if_has_namespace_delete_tangled
  local name = buf
  asm_namespaces[buf] = nil
  @retrieve_new_namespace
  @place_sentinel_in_new_namespace
  @transfer_untangled_to_new_namespace
  @generate_tangled_new_namespace_insert
  cur_delete = start_buf.next
  delete_this = cur_delete.next

  @save_new_buffer_variables
