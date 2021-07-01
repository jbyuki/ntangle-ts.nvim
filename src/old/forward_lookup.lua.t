##ntangle-ts
@implement+=
function M.lookup(buf, lnum)
  local lookup = backlookup[buf]
  local info = lookup[lnum]
  local lnum, len_prefix, root = unpack(info)
  return lnum, len_prefix, root.filename
end
