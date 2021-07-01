##ntangle-ts
@implement+=
function M.reverse_lookup(fname, lnum)
  local bufname = vim.api.nvim_buf_get_name(0)
  bufname = string.lower(bufname)
  if buf_vars[bufname] then
    local buf_asm = buf_vars[bufname].buf_asm
    local root_set = asm_namespaces[buf_asm].root_set

    for name, root in pairs(root_set) do
      if root.filename == fname then
        @find_tangled_line
        @return_lnum_of_untangled
        return nil
      end
    end
  end
end

@find_tangled_line+=
local line = root.start_file
local i = 0
while i < lnum do
  if line == root.end_file then
    line = nil
    break
  end
  line = line.next

  if line.data.linetype ~= LineType.SENTINEL then
    i = i + 1
  end
end

@return_lnum_of_untangled+=
if line then
  local untangled = line.data.untangled
  if untangled then
    return untangled.data.lnum, untangled.data.buf, untangled.data.str
  end
end
