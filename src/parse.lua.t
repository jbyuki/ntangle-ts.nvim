##ntangle-ts-next
@implement+=
function M.parse(line)
  @parse_line
  return l
end

@parse_line+=
local l = {}

@if_line_is_double_at
@if_line_is_section
@if_line_is_reference
@if_line_is_assembly
@otherwise_line_is_text

@if_line_is_double_at+=
if string.match(line, "^%s*@@") then
  @create_text_line_without_at

@if_line_is_section+=
elseif string.match(line, "^@[^@]%S*[+-]?=%s*$") then
	@parse_section_name
	@create_new_section_line

@if_line_is_reference+=
elseif string.match(line, "^%s*@[^@]%S*%s*$") then
  @get_reference_name
	@create_line_reference

@if_line_is_assembly+=
elseif string.match(line, "^##%S*%s*$") then
  @create_assembly_line

@otherwise_line_is_text+=
else
	@create_text_line
end

@create_text_line_without_at+=
local _,_,pre,post = string.find(line, '^(.*)@@(.*)$')
local text = pre .. "@" .. post
l = { 
	linetype = LineType.TEXT, 
  line = line,
	str = text 
}

@script_variables+=
local LineType = {
	@line_types
}

@line_types+=
ASSEMBLY = 5,

@create_assembly_line+=
l = {
  linetype = LineType.ASSEMBLY,
  line = line,
  str = asm,
}

@get_reference_name+=
local _, _, prefix, name = string.find(line, "^(%s*)@(%S+)%s*$")

@line_types+=
REFERENCE = 1,

@create_line_reference+=
l = { 
	linetype = LineType.REFERENCE, 
	str = name,
  line = line,
	prefix = prefix
}

@line_types+=
TEXT = 2,

@create_text_line+=
l = { 
	linetype = LineType.TEXT, 
  line = line,
	str = line 
}

@line_types+=
SECTION = 3,

@parse_section_name+=
local _, _, name, op = string.find(line, "^@(%S-)([+-]?=)%s*$")

@create_new_section_line+=
l = {
  linetype = LineType.SECTION,
  str = name,
  line = line,
  op = op,
}

@parse_variables+=
local sections_ll = {}

@add_ref_to_sections+=
sections_ll[name] = sections_ll[name] or {}

local it
if op == "-=" then
  it = linkedlist.push_front(sections_ll[name], sentinel)
else
  it = linkedlist.push_back(sections_ll[name], sentinel)
end
sentinel.data.section = it

@parse_variables+=
local roots = {}

@if_root_section_add_ref+=
if op == "=" then 
  roots[name] = {
    untangled = it,
    origin = origin,
  }
end
