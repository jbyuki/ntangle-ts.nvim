##ntangle-ts
@retrieve_lines_from_buffer+=
local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, true)

@init_incremental_tangling+=
@retrieve_lines_from_buffer

local untangled_ll = {}
local sections_ll = {}

local linecount = vim.api.nvim_buf_line_count(buf)
for i=0,linecount-1 do
  local line = vim.api.nvim_buf_get_lines(buf, i, i+1, true)[1]

  @check_if_inserted_line_is_section
  @check_if_inserted_line_is_reference
  @otherwise_inserted_line_is_text
end

-- @fill_output_buf

@script_variables+=
local getLinetype

@implement+=
function getLinetype(linetype)
  if linetype == LineType.TEXT then return "TEXT"
  elseif linetype == LineType.REFERENCE then return "REFERENCE"
  elseif linetype == LineType.SECTION then return "SECTION"
  @print_linetypes
  end
end

@call_ntangle_incremental+=
@search_untangled_node_delete
@delete_lines_incremental
@search_untangled_node_insert
@add_lines_incremental

-- @fill_output_buf

@script_variables+=
local tangleRec

@script_variables+=
local tangled_ll = {}

@line_types+=
TANGLED = 4,
SENTINEL = 5,

@print_linetypes+=
elseif linetype == LineType.TANGLED then return "TANGLED"
elseif linetype == LineType.SENTINEL then return "SENTINEL"

@implement+=
function tangleRec(name, sections_ll, tangled_ll, tangled_it, prefix, stack)
  local start_node = linkedlist.insert_after(tangled_ll, tangled_it, { 
    linetype = LineType.SENTINEL, 
    prefix = prefix, 
    line = "start " .. name 
  })

  tangled_it = start_node 

  local end_node = linkedlist.insert_after(tangled_ll, tangled_it, { 
    linetype = LineType.SENTINEL, 
    prefix = prefix, 
    line = "end " .. name 
  })

  @if_no_sections_for_name_return
  @if_already_in_stack_return
  @push_name_onto_stack

  for node in linkedlist.iter(sections_ll[name]) do
    local l = node.data
    @if_operator_add_append_before_end_node
    @if_operator_sub_append_after_start_node
    @else_operator_equal_clear_and_put_after_start_node
  end

  @pop_name_from_stack

  return start_node, end_node
end

@if_no_sections_for_name_return+=
if not sections_ll[name] then
  return start_node, end_node
end

@if_operator_add_append_before_end_node+=
if l.op == "+=" then
  local after_this = end_node.prev
  @create_sentinel_for_section
  @insert_lines_after_this

@if_operator_sub_append_after_start_node+=
elseif l.op == "-=" then
  local after_this = start_node
  @create_sentinel_for_section
  @insert_lines_after_this

@else_operator_equal_clear_and_put_after_start_node+=
else
  @clear_nodes_between_start_and_end_node
  local after_this = start_node
  @create_sentinel_for_section
  @insert_lines_after_this
end

@insert_lines_after_this+=
node = node.next
while node do
  if node.data.linetype == LineType.TEXT then
    @create_tangled_line
    @put_tangled_line_after_this
    l.untangled = node

    node.data.tangled = node.data.tangled or {}
    table.insert(node.data.tangled, after_this)
  elseif node.data.linetype == LineType.REFERENCE then
    local ref_start, ref_end = tangleRec(node.data.str, sections_ll, tangled_ll, after_this, prefix .. node.data.prefix, stack)
    node.data.tangled = node.data.tangled or {}
    table.insert(node.data.tangled, {ref_start, ref_end})

    ref_start.data.untangled = node
    ref_end.data.untangled = node
    ref_end.data.prefix = node.data.prefix

    after_this = ref_end
  elseif node.data.linetype == LineType.SECTION then
    break
  end
  node = node.next
end

@create_sentinel_for_section+=
local section_sentinel = linkedlist.insert_after(tangled_ll, after_this, { 
  linetype = LineType.SENTINEL, 
  prefix = after_this.node.prefix,
  untangled = node
})
l.tangled = l.tangled or {}
table.insert(l.tangled, section_sentinel)

@create_tangled_line+=
local l = { 
  linetype = LineType.TANGLED, 
  prefix = prefix,
  line = prefix .. node.data.str,
}

@put_tangled_line_after_this+=
after_this = linkedlist.insert_after(tangled_ll, after_this, l)

@search_untangled_node_delete+=
local delete_this = untangled_ll.head
for _=1,firstline do
  delete_this = delete_this.next
end

@delete_lines_incremental+=
for _=firstline,lastline-1 do
  local cur_delete = delete_this
  if not cur_delete then break end
  delete_this = delete_this.next

  @check_if_deleted_line_is_section
  @check_if_deleted_line_is_reference
  @otherwise_deleted_line_is_text

  @remove_in_untangled
end

@check_if_deleted_line_is_section+=
if cur_delete.data.linetype == LineType.SECTION then
  local insert_after = cur_delete
  @remove_sentinel_or_bisentinel
  @remove_lines_after_section_in_untangled_in_tangled
  @remove_in_untangled
  @add_lines_back_to_section
  cur_delete = nil

@remove_sentinel_or_bisentinel+=
if cur_delete.data.op == "=" then
  @remove_bisentinel
  @remove_from_roots
else
  for _, ref in ipairs(cur_delete.data.tangled) do
    linkedlist.remove(tangled_ll, ref)
  end
end

@remove_bisentinel+=
linkedlist.remove(tangled_ll, cur_delete.data.tangled[1])
linkedlist.remove(tangled_ll, cur_delete.data.extra_tangled)

@remove_from_roots+=
root_set[cur_delete.data.str] = nil

@check_if_deleted_line_is_reference+=
elseif cur_delete.data.linetype == LineType.REFERENCE then
  for _, ref in ipairs(cur_delete.data.tangled) do
    local ref_start, ref_end = unpack(ref)
    local copy = ref_start
    local quit = false
    while copy and not quit do
      if copy == ref_end then quit = true end
      local to_delete = copy
      @remove_reference_to_tangled_node
      linkedlist.remove(tangled_ll, to_delete)
      copy = copy.next
    end
  end

@remove_reference_to_tangled_node+=
local untangled = to_delete.data.untangled
if not untangled then
  print("Something went south.")
elseif untangled.data.linetype == LineType.TEXT then
  untangled.data.tangled = vim.tbl_filter(function(x) return x ~= to_delete end, untangled.data.tangled)
elseif untangled.data.linetype == LineType.REFERENCE then
  untangled.data.tangled = vim.tbl_filter(function(x) return x[1] ~= to_delete and x[2] ~= to_delete end, untangled.data.tangled)
elseif untangled.data.linetype == LineType.SECTION then
  untangled.data.tangled = vim.tbl_filter(function(x) return x ~= to_delete end, untangled.data.tangled)
end

@otherwise_deleted_line_is_text+=
else
  @remove_text_in_tangled
end

@remove_text_in_tangled+=
if cur_delete.data.tangled then
  for _, ref in ipairs(cur_delete.data.tangled) do
    linkedlist.remove(tangled_ll, ref)
  end
end

@remove_in_untangled+=
if cur_delete then
  linkedlist.remove(untangled_ll, cur_delete)
end

@add_lines_incremental+=
for i=firstline,new_lastline-1 do
  local line = vim.api.nvim_buf_get_lines(buf, i, i+1, true)[1]

  @check_if_inserted_line_is_section
  @check_if_inserted_line_is_reference
  @otherwise_inserted_line_is_text
end

@check_if_inserted_line_is_section+=
if string.match(line, "^@[^@]%S*[+-]?=%s*$") then
  @parse_section_name
  @create_line_section
  @add_line_after_untangled_node
  @insert_entry_to_sections
  @find_preceding_section_for_operator
  @if_none_find_all_references
  @insert_sentinel_for_section

  @if_root_section_add_bisentinels

  @remove_lines_after_section_in_untangled_in_tangled
  @add_lines_back_to_section

@create_line_section+=
local l = { linetype = LineType.SECTION, str = name, op = op }

@insert_entry_to_sections+=
local it = insert_after and insert_after.prev
while it do
  if it.data.linetype == LineType.SECTION and it.data.str == name then
    break
  end
  it = it.prev
end

local section
if it then
  section = linkedlist.insert_after(sections_ll[name], it.data.section, insert_after)
  insert_after.data.section = section
else
  sections_ll[name] = sections_ll[name] or {}
  section = linkedlist.push_front(sections_ll[name], insert_after)
end
l.section = section

@find_preceding_section_for_operator+=
local ref_it
if op == "+=" then
  section = section.next
  while section do
    local it = section.data
    if it.data.op == "+=" then
      ref_it = it.data.tangled
    end
    section = section.next
  end
elseif op == "-=" then
  section = section.prev
  while section do
    local it = section.data
    if it.data.op == "-=" then
      ref_it = it.data.tangled
      break
    end
    section = section.prev
  end
end

@if_none_find_all_references+=
if not ref_it then
  if op == "+=" then
    ref_it = {}
    for line in linkedlist.iter(untangled_ll) do
      if line.linetype == LineType.REFERENCE and line.str == name then
        for _, ref in ipairs(line.tangled) do
          table.insert(ref_it, ref[2])
        end
      end
    end
  elseif op == "-=" then
    ref_it = {}
    for line in linkedlist.iter(untangled_ll) do
      if line.linetype == LineType.REFERENCE and line.str == name then
        for _, ref in ipairs(line.tangled) do
          table.insert(ref_it, ref[1])
        end
      end
    end
  end
end

@insert_sentinel_for_section+=
l.tangled = {}
if op == "+=" then
  for _, ref in ipairs(ref_it) do
    local section = linkedlist.insert_before(tangled_ll, ref, {
      linetype = LineType.SENTINEL,
      prefix = ref.prev.data.prefix,
      untangled = insert_after
    })
    table.insert(l.tangled, section)
  end
elseif op == "-=" then
  for _, ref in ipairs(ref_it) do
    local section = linkedlist.insert_after(tangled_ll, ref, {
      linetype = LineType.SENTINEL,
      prefix = ref.data.prefix,
      untangled = insert_after
    })
    table.insert(l.tangled, section)
  end
end

@if_root_section_add_bisentinels+=
if op == "=" then
  local start_file = linkedlist.push_back(tangled_ll, {
    linetype = LineType.SENTINEL,
    prefix = "",
    line = "START " .. name,
    untangled = insert_after,
  })

  local end_file = linkedlist.push_back(tangled_ll, {
    linetype = LineType.SENTINEL,
    prefix = "",
    line = "END " .. name,
    untangled = insert_after,
  })

  l.tangled = { start_file }
  l.extra_tangled = end_file
  root_set[l.str] = insert_after
end

@init_incremental_tangling-=
local root_set = {}

@remove_lines_after_section_in_untangled_in_tangled+=
local it = insert_after and insert_after.next
while it do
  local cur_delete = it
  if it.data.linetype == LineType.SECTION then
    break
  @check_if_deleted_line_is_reference
  @otherwise_deleted_line_is_text
  it = it.next
end

@add_lines_back_to_section+=
local it = insert_after and insert_after.next
while it do
  local insert_after = it.prev
  if it.data.linetype == LineType.SECTION then
    break
  @check_if_reference_insert_back
  @otherwise_text_insert_back
  it = it.next
end

@check_if_reference_insert_back+=
elseif it.data.linetype == LineType.REFERENCE then
  local l = it.data
  @get_all_tangled_node
  local name = it.data.str
  @add_reference_to_all_tangled

@otherwise_text_insert_back+=
else
  local l = it.data
  local line = l.str
  @get_all_tangled_node
  @add_text_to_all_tangled
end

@check_if_inserted_line_is_reference+=
elseif string.match(line, "^%s*@[^@]%S*%s*$") then
  @get_reference_name
	@create_line_reference
  @get_all_tangled_node
  @add_line_after_untangled_node
  local it = insert_after
  @add_reference_to_all_tangled

@otherwise_inserted_line_is_text+=
else
  @create_text_line
  @get_all_tangled_node
  @add_line_after_untangled_node
  local it = insert_after
  @add_text_to_all_tangled
end

@search_untangled_node_insert+=
local insert_after = untangled_ll.head
for _=1,firstline-1 do
  insert_after = insert_after.next
end

if firstline == 0 then
  insert_after = nil
end

@add_line_after_untangled_node+=
insert_after = linkedlist.insert_after(untangled_ll, insert_after, l)

@get_all_tangled_node+=
local tangled = {}
if insert_after then
  if insert_after.data.linetype == LineType.TEXT then
    for _, ref in ipairs(insert_after.data.tangled) do
      table.insert(tangled, ref)
    end
  elseif insert_after.data.linetype == LineType.REFERENCE then
    for _, ref in ipairs(insert_after.data.tangled) do
      local start_ref, end_ref = unpack(ref)
      table.insert(tangled, end_ref)
    end
  elseif insert_after.data.linetype == LineType.SECTION then
    for _, ref in ipairs(insert_after.data.tangled) do
      table.insert(tangled, ref)
    end
  end
end

@add_reference_to_all_tangled+=
l.tangled = {}
for _, ref in ipairs(tangled) do
  local ref_start, ref_end = tangleRec(name, sections_ll, tangled_ll, ref, ref.data.prefix .. l.prefix, {})
  table.insert(l.tangled, {ref_start, ref_end})
  ref_start.data.untangled = it
  ref_end.data.untangled = it
  ref_end.data.prefix = ref.data.prefix
end

@add_text_to_all_tangled+=
l.tangled = {}
if tangled then
  for _, ref in ipairs(tangled) do
    local new_node = linkedlist.insert_after(tangled_ll, ref, {
      linetype = LineType.TANGLED,
      prefix = ref.data.prefix,
      line = ref.data.prefix .. line,
      untangled = it,
    })
    table.insert(l.tangled, new_node)
  end
end

@fill_output_buf+=
if outputbuf then
  vim.schedule(function()
    local lines = {}
    for line in linkedlist.iter(tangled_ll) do
      if line.linetype == LineType.TANGLED then
        table.insert(lines, line.line)
      end
    end
    vim.api.nvim_buf_set_lines(outputbuf, 0, -1, true, lines)
  end)
else
  print("UNTANGLED")
  for line in linkedlist.iter(untangled_ll) do
    print(getLinetype(line.linetype) .. " " .. vim.inspect(line.line))
  end
  print("TANGLED")
  for line in linkedlist.iter(tangled_ll) do
    print(getLinetype(line.linetype) .. " " .. vim.inspect(line.line) .. " " .. vim.inspect(line.prefix))
  end
  -- print("ROOTS")
  -- for name,_ in pairs(root_set) do
    -- print(name)
  -- end
end

@push_name_onto_stack+=
table.insert(stack, name)

@pop_name_from_stack+=
table.remove(stack)

@if_already_in_stack_return+=
if vim.tbl_contains(stack, name) then
  return start_node, end_node
end

@script_variables+=
local LineType = {
	@line_types
}

@line_types+=
REFERENCE = 1,
TEXT = 2,
SECTION = 3,

