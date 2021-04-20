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
  @generate_tangled_new_namespace

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

@setup_initial_namespace_to_buffer+=
asm_namespaces[buf] = {
  untangled_ll = {},
  tangled_ll = {},
  sections_ll = {},
  root_set = {},
  parts_ll = {},
}

local untangled_ll = asm_namespaces[buf].untangled_ll
local sections_ll = asm_namespaces[buf].sections_ll
local tangled_ll = asm_namespaces[buf].tangled_ll
local root_set = asm_namespaces[buf].root_set
local parts_ll = asm_namespaces[buf].parts_ll

@create_untangled_start_end_sentinel

@if_has_namespace_delete_tangled+=
if buf_asm then
  @delete_tangled_line_one_by_one
  @delete_part_in_parts
end

@buffer_variables+=
local start_buf, end_buf

@line_types+=
BUF_DELIM,

@print_linetypes+=
elseif linetype == LineType.BUF_DELIM then
  return "BUFDELIM"

@create_untangled_start_end_sentinel+=
start_buf = linkedlist.push_back(untangled_ll, {
  linetype = BUF_DELIM,
  buf = buf,
  str = "START " .. buf,
})

end_buf = linkedlist.push_back(untangled_ll, {
  linetype = BUF_DELIM,
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

  @check_if_deleted_line_is_section
  @check_if_deleted_line_is_reference
  @otherwise_deleted_line_is_text
end

@retrieve_new_namespace+=
local old_untangled_ll = untangled_ll

local check_links = false
if not asm_namespaces[name] then
  @create_new_namespace
  check_links = true
end

local untangled_ll = asm_namespaces[name].untangled_ll
local sections_ll = asm_namespaces[name].sections_ll
local tangled_ll = asm_namespaces[name].tangled_ll
local root_set = asm_namespaces[name].root_set
local parts_ll = asm_namespaces[name].parts_ll

if check_links then
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
		@append_lines_from_part_file
	end
end

@read_link_from_link_file+=
local f = io.open(part, "r")
local origin_path = f:read("*line")
f:close()

@append_lines_from_part_file+=
local f = io.open(origin_path, "r")
if f then
  @create_start_and_end_sentinel_for_part
	local lnum = 1
  local insert_after = start_part
	while true do
		local line = f:read("*line")
		if not line then break end
		if lnum > 1 then
      @check_if_inserted_line_is_section
      @check_if_inserted_line_is_reference
      @otherwise_inserted_line_is_text
		end
		lnum = lnum + 1
	end
	f:close()
end

@create_start_and_end_sentinel_for_part+=
local start_part = linkedlist.push_back(untangled_ll, {
  linetype = BUF_DELIM,
  str = "START " .. origin_path,
})

local end_part = linkedlist.push_back(untangled_ll, {
  linetype = BUF_DELIM,
  str = "END " .. origin_path,
})

linkedlist.push_back(parts_ll, {
  start_buf = start_part,
  end_buf = end_part,
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
  part_after = part_after.next
  if part_after.data.name > cur_name then
    break
  end
end

local new_start_buf, new_end_buf
if not part_after then
  @push_part_sentinel_at_end
else
  @insert_part_sentinel_in_between
end

@push_part_sentinel_at_end+=
new_start_buf = linkedlist.push_back(untangled_ll, {
  linetype = BUF_DELIM,
  buf = buf,
  str = "START " .. buf,
})

new_end_buf = linkedlist.push_back(untangled_ll, {
  linetype = BUF_DELIM,
  buf = buf,
  str = "END " .. buf,
})

linkedlist.push_back(parts_ll, {
  start_buf = start_buf,
  end_buf = end_buf,
  name = vim.api.nvim_buf_get_name(buf),
})

@insert_part_sentinel_in_between+=
local end_buf_after = part_after.data.start_buf

new_start_buf = linkedlist.insert_before(untangled_ll, end_buf_after, {
  linetype = BUF_DELIM,
  buf = buf,
  str = "START " .. buf,
})

new_end_buf = linkedlist.insert_before(untangled_ll, end_buf_after, {
  linetype = BUF_DELIM,
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
local insert_after = new_start_buf
while transfer_this ~= end_buf do
  insert_after = linkedlist.insert_after(untangled_ll, insert_after, transfer_this.data)
  local delete_this = transfer_this
  transfer_this = transfer_this.next
  linkedlist.remove(old_untangled_ll, delete_this)
end

linkedlist.remove(old_untangled_ll, start_buf)
linkedlist.remove(old_untangled_ll, end_buf)
old_untangled_ll = nil
start_buf = new_start_buf
end_buf = new_end_buf

@generate_tangled_new_namespace+=
local insert_after = start_buf
@add_lines_back_to_section

@line_types+=
ASSEMBLY,

@print_linetypes+=
elseif linetype == LineType.ASSEMBLY then return "ASSEMBLY"

@create_assembly_line+=
local l = {
  linetype = LineType.ASSEMBLY,
  str = name,
}

@append_assembly_to_untangled+=
linkedlist.insert_after(untangled_ll, start_buf, l)
