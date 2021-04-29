##ntangle-ts
@update_line_number_untangled+=
for buf, sent in pairs(bufs_set) do
  local start_buf, end_buf = unpack(sent)
  local lnum = 1
  local it = start_buf.next
  while it ~= end_buf do
    it.data.lnum = lnum
    it.data.buf = buf
    lnum = lnum + 1
    it = it.next
  end
end

@fill_lookup_table+=
local lookups = {}

for name, root in pairs(root_set) do
  local start_file = root.start_file
  local end_file = root.end_file
  local tree = root.tree

  local tangle_lnum = 1

  local it = start_file
  while it ~= end_file do
    local line = it.data
    if line.linetype == LineType.TANGLED then
      local lookup_buf = line.untangled.data.buf
      if lookup_buf then
        lookups[lookup_buf] = lookups[lookup_buf] or {}
        local lookup = lookups[lookup_buf]
        lookup[line.untangled.data.lnum] = { tangle_lnum, string.len(line.prefix), tree, root.sources }
      end
      tangle_lnum = tangle_lnum + 1
    end

    it = it.next
  end
end


for buf, lookup in pairs(lookups) do
  backlookup[buf] = lookup
end

@generate_tangled_code+=
for name, root in pairs(root_set) do
  local start_file = root.start_file
  local end_file = root.end_file

  local source_lines = {}

  local it = start_file
  while it ~= end_file do
    local line = it.data
    if line.linetype == LineType.TANGLED then
      table.insert(source_lines, line.line)
    end
    it = it.next
  end

  root.sources = table.concat(source_lines, "\n")
end
