##ntangle-ts
@update_line_number_untangled+=
local lnum = 1
local it = start_buf.next
while it ~= end_buf do
  it.data.lnum = lnum
  it.data.buf = buf
  lnum = lnum + 1
  it = it.next
end

@fill_lookup_table+=
local lookup = {}

for name, root in pairs(root_set) do
  local start_file = root.start_file
  local end_file = root.end_file
  local tree = root.tree

  local tangle_lnum = 1

  local it = start_file
  while it ~= end_file do
    local line = it.data
    if line.linetype == LineType.TANGLED then
      if line.untangled.data.buf == buf then
        lookup[line.untangled.data.lnum] = { tangle_lnum, string.len(line.prefix), tree, root.sources }
      end
      tangle_lnum = tangle_lnum + 1
    end

    it = it.next
  end
end

backlookup[buf] = lookup

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
