##ntangle-ts
@find_root_section_filename+=
local filename
local buf_asm = (buf_vars[bufname] and buf_vars[bufname].buf_asm) or ""

@extract_assembly_parent_directory

local root_name = name
if name == "*" then
  root_name = "tangle/" .. vim.fn.fnamemodify(bufname, ":t:r")
else
	if string.find(name, "/") then
		root_name = name
	else
		root_name = "tangle/" .. name
	end
end

local cur_dir = vim.fn.fnamemodify(bufname, ":h")
filename = cur_dir .. "/" .. parent_assembly .. "/" .. root_name
filename = string.lower(filename)

@extract_assembly_parent_directory+=
local parent_assembly
parent_assembly = vim.fn.fnamemodify(buf_asm, ":h")
