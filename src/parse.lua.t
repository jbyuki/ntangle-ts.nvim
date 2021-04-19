##ntangle-ts
@parse_section_name+=
local _, _, name, op = string.find(line, "^@(%S-)([+-]?=)%s*$")

@get_reference_name+=
local _, _, prefix, name = string.find(line, "^(%s*)@(%S+)%s*$")
if name == nil then
	print(line)
end

@create_line_reference+=
local l = { 
	linetype = LineType.REFERENCE, 
	str = name,
	prefix = prefix
}

@create_text_line+=
local l = { 
	linetype = LineType.TEXT, 
	str = line 
}
