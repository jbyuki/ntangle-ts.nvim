##ntangle-ts-next
@implement+=
function M.attach()
  @get_buffer_content
  @init_untangled_content

  @insert_sentinel_at_every_line
  @parse_variables
  @parse_line_and_save_in_sentinel

  @compute_reference_sizes
  @save_section_dependencies

  @generate_initial_tangled

  @clear_virtual_text_namespace
  @show_line_as_virtual_text

  @attach_functions

  vim.api.nvim_buf_attach(0, true, {
    on_bytes = function(_, _, _, 
      start_row, start_col, start_byte, 
      old_row, old_col, old_byte, 
      new_row, new_col, new_byte)
      @search_start_range_character
      @delete_characters
      @insert_characters

      @send_bytes_events

      @remove_deleted_and_inserted_chars
      @put_new_parsed
      @recompute_section_sizes

      @clear_virtual_text_namespace
      @show_line_as_virtual_text
    end
  })
end

@get_buffer_content+=
local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)

@init_untangled_content+=
local text = table.concat(lines, "\n")
for i=1,string.len(text) do
  local c = string.sub(text, i, i)

  @create_character_data
  @append_character_to_linked_list
end

@script_variables+=
local untangled = {}

@implement+=
function untangled.new(t)
  local o = {
    ["type"] = UNTANGLED[t],
  }
  return setmetatable(o, { __index = untangled  })
end

@create_character_data+=
local d = untangled.new("CHAR")
d.sym = c

@script_variables+=
local UNTANGLED = {
  @untangled_types
}

@untangled_types+=
CHAR = 1,

@init_untangled_content-=
local content = {}

@append_character_to_linked_list+=
linkedlist.push_back(content, d)

@insert_sentinel_at_every_line+=
local cur = content.head
@insert_first_line_sentinel
while cur do
  @insert_sentinel_after_newline
  cur = cur.next
end

@untangled_types+=
SENTINEL = 2,

@insert_first_line_sentinel+=
local d = untangled.new("SENTINEL")

if cur then
  linkedlist.insert_before(content, cur, d)
else
  linkedlist.push_back(content, d)
end

@implement+=
function untangled:is_newline()
  return self.type == UNTANGLED.CHAR and self.sym == '\n'
end

@insert_sentinel_after_newline+=
if cur.data:is_newline() then
  @insert_sentinel_after
end

@insert_sentinel_after+=
local d = untangled.new("SENTINEL")
linkedlist.insert_after(content, cur, d)

@parse_line_and_save_in_sentinel+=
local cur = content.head
assert(cur.data.type == UNTANGLED.SENTINEL, "First element in untangled must be a sentinel")
while cur do
  local sentinel = cur
  cur = cur.next
  @collect_letter_on_line
  local l = M.parse(line)
  if l.linetype == LineType.SECTION then
    local name, op = l.str, l.op
    @add_ref_to_sections
    @if_root_section_add_ref
  end

  @put_parsed_informations_in_sentinel
end

@collect_letter_on_line+=
local line = ""
local changed = false
while cur do
  if cur.data:is_newline() then
    cur = cur.next
    break
  end

  if cur.data.type == UNTANGLED.CHAR and not cur.data.deleted then
    line = line .. cur.data.sym
  end

  if cur.data.deleted or cur.data.inserted then
    changed = true
  end
  cur = cur.next
end

@put_parsed_informations_in_sentinel+=
sentinel.data.parsed = l

@generate_initial_tangled+=
local generate 
generate = function(name, lines) 
  if not sections_ll[name] then
    return
  end

  for cur in linkedlist.iter(sections_ll[name]) do
    cur = cur.next
    while cur do
      @go_to_next_sentinel
      if not cur then break end
      local l = cur.data.parsed
      @if_text_output
      @if_reference_recurse
      @if_section_break
    end
  end
end

for name, _ in pairs(roots) do
  local lines = {}
  generate(name, lines)
  -- @display_generated_lines
end

@display_generated_lines+=
print("ROOT", name)
for lnum, line in ipairs(lines) do
  print(lnum, vim.inspect(line))
end


@go_to_next_sentinel+=
while cur do
  if cur.data.type == UNTANGLED.SENTINEL then
    break
  end
  cur = cur.next
end

@if_text_output+=
if l.linetype == LineType.TEXT then
  @collect_letter_on_line
  table.insert(lines, line)

@if_reference_recurse+=
elseif l.linetype == LineType.REFERENCE then
  generate(l.str, lines)
  cur = cur.next

@if_section_break+=
elseif l.linetype == LineType.SECTION then
  break
end

@parse_variables+=
local ref_sizes = {}

@compute_reference_sizes+=
local compute_sizes
compute_sizes = function(name) 
  if not sections_ll[name] then
    return 0
  end

  if ref_sizes[name] then
    return ref_sizes[name]
  end

  local size = 0
  for cur in linkedlist.iter(sections_ll[name]) do
    cur = cur.next
    while cur do
      @go_to_next_sentinel
      if not cur then break end
      local l = cur.data.parsed
      @if_text_add_to_size
      @if_reference_recursve_and_add
      @if_section_break
    end
  end
  ref_sizes[name] = size
  return size
end

for name, _ in pairs(roots) do
  compute_sizes(name)
end

@if_text_add_to_size+=
if l.linetype == LineType.TEXT then
  @count_chars_until_next_sentinel
  -- cur.data.len = len
  size = size + len

@count_chars_until_next_sentinel+=
cur = cur.next
local len = 0
while cur do
  if cur.data.type == UNTANGLED.CHAR then
    len = len + string.len(cur.data.sym)
  elseif cur.data.type == UNTANGLED.SENTINEL then
    break
  end
  cur = cur.next
end

@if_reference_recursve_and_add+=
elseif l.linetype == LineType.REFERENCE then
  local len = compute_sizes(l.str)
  cur.data.len = len
  size = size + len
  cur = cur.next

@parse_variables+=
local deps = {}

@save_section_dependencies+=
local build_dep
build_dep = function(name)
  if not sections_ll[name] then
    return
  end

  for cur in linkedlist.iter(sections_ll[name]) do
    cur = cur.next
    while cur do
      @go_to_next_sentinel
      if not cur then break end
      local l = cur.data.parsed
      @if_reference_add_to_deps
      @if_section_break
      cur = cur.next
    end
  end
end

for name, _ in pairs(roots) do
  build_dep(name)
end

@if_reference_add_to_deps+=
if l.linetype == LineType.REFERENCE then
  deps[l.str] = deps[l.str] or {}
  deps[l.str][name] = true
  build_dep(l.str)


@search_start_range_character+=
local cur = content.head
local sentinel
local section
local cur_byte = 0
while cur do
  if cur.data.type == UNTANGLED.CHAR then
    if cur_byte == start_byte then 
      break 
    end
    cur_byte = cur_byte + string.len(cur.data.sym)
  elseif cur.data.type == UNTANGLED.SENTINEL then
    sentinel = cur
    @if_section_set_containing
  end
  cur = cur.next
end

@if_section_set_containing+=
local l = sentinel.data.parsed
if l.linetype == LineType.SECTION then
  section = l.str
end

@delete_characters+=
local start = cur

local dirty = {}
local to_delete = {}

for i=1,old_byte do
  if not cur then
    break
  end
  @mark_char_as_deleted
  @mark_all_containing_sections_as_dirty
  @go_to_next_char
end


@append_sentinel_to_reparse+=
if sentinel then
  table.insert(reparse, sentinel)
end
sentinel = nil

@mark_char_as_deleted+=
cur.data.deleted = true
table.insert(to_delete, cur)

@parse_variables+=
local mark_dirty
mark_dirty = function(name, dirty) 
  if dirty[name] then
    return
  end

  dirty[name] = true
  if deps[name] then
    for d, _ in pairs(deps[name]) do
      mark_dirty(d, dirty)
    end
  end
end

@mark_all_containing_sections_as_dirty+=
if section then
  mark_dirty(section, dirty)
end


@go_to_next_char+=
while cur do
  cur = cur.next
  if cur.data.type == UNTANGLED.SENTINEL then
    sentinel = cur
    @if_section_set_containing
  end

  if cur.data.type == UNTANGLED.CHAR then
    break
  end
end


@insert_characters+=
local cur = start
local to_insert = {}
@get_inserted_characters_from_buffer
@skip_deleted_characters
@check_start_pointer_position
@mark_all_containing_sections_as_dirty
for i=1,new_byte do
  local c = string.sub(text, i, i)
  @insert_char_after
  @adjust_start_pointer_position
end

@get_inserted_characters_from_buffer+=
local lines = vim.api.nvim_buf_get_lines(0, start_row, start_row+new_row+1, true)
lines[1] = string.sub(lines[1], start_col+1)
lines[#lines] = string.sub(lines[#lines], 1, new_col)
local text = table.concat(lines, "\n")

@skip_deleted_characters+=
local prev
prev = cur.prev
while cur do
  if not cur.data.deleted then
    break
  end
  prev = cur
  cur = cur.next
end
cur = prev

@check_start_pointer_position+=
local shifted = false
if cur == start.prev then
  shifted = true
end

@adjust_start_pointer_position+=
if i == 1 and shifted then
  start = cur
end

@insert_char_after+=
local n = untangled.new("CHAR")
n.sym = c
n.inserted = true

cur = linkedlist.insert_after(content, cur, n)
table.insert(to_insert, cur)

@send_bytes_events+=
local scan_changes
scan_changes = function(name, offset, changes, start)
  if not sections_ll[name] then
    return
  end

  for cur in linkedlist.iter(sections_ll[name]) do
    cur = cur.next
    while cur do
      @go_to_next_sentinel
      if not cur then break end
      local l = cur.data.parsed
      @if_text_scan_line
      @if_reference_recurse_if_dirty
      @if_section_break
    end
  end
  return offset
end

@send_bytes_events+=
for name, _ in pairs(roots) do
  if dirty[name] then
    local changes = {}
    scan_changes(name, 0, changes, start)
    print("changes", vim.inspect(changes))
  end
end

@if_text_scan_line+=
if l.linetype == LineType.TEXT then
  local sentinel = cur
  @collect_letter_on_line
  @reparse_if_changed

  if new_l then
    cur = sentinel
    if new_l.linetype == LineType.TEXT then
      @scan_for_changes_in_text
    elseif new_l.linetype == LineType.REFERENCE then
      @count_inserted_reference_content
      @count_chars_until_next_sentinel_not_inserted
      @add_text_to_reference_change
    end
  else
    cur = sentinel
    @count_chars_until_next_sentinel
    offset = offset + len
  end

@scan_for_changes_in_text+=
cur = cur.next
while cur do
  if cur == start then
    @count_deleted_characters
    @count_inserted_characters
    @append_change_text
  end

  if cur.data.type == UNTANGLED.CHAR then
    if not cur.data.deleted then
      offset = offset + 1
    end
  elseif cur.data.type == UNTANGLED.SENTINEL then
    break
  end
  cur = cur.next
end

@count_deleted_characters+=
local deleted = 0
while cur do
  if not cur.data.deleted then
    break
  end
  deleted = deleted + 1
  cur = cur.next
end

@count_inserted_characters+=
local inserted = 0
while cur do
  if not cur.data.inserted then
    break
  end
  inserted = inserted + 1
  cur = cur.next
end

@append_change_text+=
table.insert(changes, { offset, deleted, inserted })

@add_text_to_reference_change+=
table.insert(changes, { offset, len, inserted })

@if_reference_recurse_if_dirty+=
elseif l.linetype == LineType.REFERENCE then
  local sentinel = cur
  cur = cur.next
  @collect_letter_on_line
  @reparse_if_changed

  if new_l then
    if new_l.linetype == LineType.TEXT then
      @count_deleted_reference_content
      cur = sentinel
      @count_chars_until_next_sentinel_not_deleted
      @append_to_reparsed
      @add_reference_to_text_changes
      offset = offset + len
    elseif new_l.linetype == LineType.REFERENCE then
      @count_deleted_reference_content
      @count_inserted_reference_content
      @add_reference_changes
      l.str = new_ref
    end
  else
    if dirty[l.str] then
      offset = scan_changes(l.str, offset, changes, start)
    else
      if ref_sizes[l.str] then
        offset = offset + ref_sizes[l.str]
      end
    end
  end

@reparse_if_changed+=
local new_l 
if changed then
  new_l = M.parse(line)
end

@send_bytes_events-=
local reparsed = {}

@append_to_reparsed+=
sentinel.data.new_parsed = new_l
table.insert(reparsed, sentinel)

@put_new_parsed+=
for _, n in ipairs(reparsed) do
  if n.data.new_parsed then
    n.data.parsed = n.data.new_parsed
    n.data.new_parsed = nil
  end
end
reparsed = {}

@add_reference_to_text_changes+=
table.insert(changes, { offset, deleted, len })

@attach_functions+=
local size_deleted
size_deleted = function(name, deleted_ref) 
  if not sections_ll[name] then
    return 0
  end

  if deleted_ref[name] then
    return deleted_ref[name]
  end
  
  local size = 0
  for cur in linkedlist.iter(sections_ll[name]) do
    cur = cur.next
    while cur do
      @go_to_next_sentinel
      if not cur then break end
      local l = cur.data.parsed
      @if_text_add_to_size_not_inserted
      @if_reference_recursve_and_add_deleted
      @if_section_break
    end
  end
  deleted_ref[name] = size
  return size
end

@if_text_add_to_size_not_inserted+=
if l.linetype == LineType.TEXT then
  @count_chars_until_next_sentinel_not_inserted
  -- cur.data.len = len
  size = size + len

@count_chars_until_next_sentinel_not_inserted+=
cur = cur.next
local len = 0
while cur do
  if cur.data.type == UNTANGLED.CHAR and not cur.data.inserted then
    len = len + string.len(cur.data.sym)
  elseif cur.data.type == UNTANGLED.SENTINEL then
    break
  end
  cur = cur.next
end

@if_reference_recursve_and_add_deleted+=
elseif l.linetype == LineType.REFERENCE then
  local len = size_deleted(l.str)
  size = size + len
  cur = cur.next

@count_deleted_reference_content+=
local deleted_ref = {}
local deleted = size_deleted(l.str, deleted_ref)

@attach_functions+=
local size_inserted
size_inserted = function(name, inserted_ref) 
  if not sections_ll[name] then
    return 0
  end

  if inserted_ref[name] then
    return inserted_ref[name]
  end
  
  local size = 0
  for cur in linkedlist.iter(sections_ll[name]) do
    cur = cur.next
    while cur do
      @go_to_next_sentinel
      if not cur then break end
      local l = cur.data.new_parsed or cur.data.parsed
      @if_text_add_to_size_not_deleted
      @if_reference_recursve_and_add_inserted
      @if_section_break
    end
  end
  inserted_ref[name] = size
  return size
end

@if_text_add_to_size_not_deleted+=
if l.linetype == LineType.TEXT then
  @count_chars_until_next_sentinel_not_deleted
  -- cur.data.len = len
  size = size + len

@count_chars_until_next_sentinel_not_deleted+=
cur = cur.next
local len = 0
while cur do
  if cur.data.type == UNTANGLED.CHAR and not cur.data.deleted then
    len = len + string.len(cur.data.sym)
  elseif cur.data.type == UNTANGLED.SENTINEL then
    break
  end
  cur = cur.next
end

@if_reference_recursve_and_add_inserted+=
elseif l.linetype == LineType.REFERENCE then
  local len = size_inserted(l.str)
  size = size + len
  cur = cur.next

@count_inserted_reference_content+=
local inserted_ref = {}
local inserted = size_inserted(new_l.str, inserted_ref)

@add_reference_changes+=
table.insert(changes, { offset, deleted, inserted })

@remove_deleted_and_inserted_chars+=
for _, n in ipairs(to_delete) do
  linkedlist.remove(content, n)
end

for _, n in ipairs(to_insert) do
  n.data.inserted = nil
end

@recompute_section_sizes+=
for name, _ in pairs(dirty) do
  ref_sizes[name] = nil
end

for name, _ in pairs(roots) do
  if dirty[name] then
    compute_sizes(name)
  end
end

@script_variables+=
local ns_debug = vim.api.nvim_create_namespace("")

@clear_virtual_text_namespace+=
vim.api.nvim_buf_clear_namespace(0, ns_debug, 0, -1)

@show_line_as_virtual_text+=
local lnum = 0
local cur = content.head
while cur do
  local sentinel = cur
  cur = cur.next
  @collect_letter_on_line
  @get_linetype
  @display_line_as_virtual_text
  lnum = lnum + 1
end

@display_line_as_virtual_text+=
vim.api.nvim_buf_set_extmark(0, ns_debug, lnum, 0, {
  virt_text = {{line, "NonText"}, {"[" .. linetype .. "]", "WarningMsg"}}
})

@get_linetype+=
local linetype = "UNKNOWN"
local l = sentinel.data.parsed
if l then
  if l.linetype == LineType.TEXT then
    linetype = "TEXT"
  elseif l.linetype == LineType.REFERENCE then
    linetype = "REF"
  elseif l.linetype == LineType.SECTION then
    linetype = "SECTION"
  end
end
