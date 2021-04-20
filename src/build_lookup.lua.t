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

@script_variables+=
local backlookup = {}

@fill_lookup_table+=
local lookup = {}

local tangle_lnum = 1
for line in linkedlist.iter(tangled_ll) do
  if line.linetype == LineType.TANGLED then
    if line.untangled.data.buf == buf then
      lookup[line.untangled.data.lnum] = { tangle_lnum, string.len(line.prefix) }
    end
    tangle_lnum = tangle_lnum + 1
  end
end

backlookup[buf] = lookup

@generate_tangled_code+=
local source_lines = {}

for line in linkedlist.iter(tangled_ll) do
  if line.linetype == LineType.TANGLED then
    table.insert(source_lines, line.line)
  end
end

sources[buf] = table.concat(source_lines, "\n")
