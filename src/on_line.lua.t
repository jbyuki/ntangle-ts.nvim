##ntangle-ts
@implement+=
function M._on_line(...)
  local _, _, buf, line = unpack({...})
  @if_has_attach_override
  -- @test_override
  @otherwise_run_default_highlighter
end

@script_variables+=
local backbuf = {}

@if_has_attach_override+=
if backbuf[buf] then
  @convert_line_number_to_untangled
  if lookup and lookup[line+1] then
    local tline = line
    local line, indent, tstree, sources = unpack(lookup[line+1])
    line = line - 1
    @get_current_highlighter
    @highlight_from_backbuf
    -- @highlight_line_test
  else
    @highlight_ntangle_lines
  end

@otherwise_run_default_highlighter+=
else
  highlighter._on_line(...)
end

@highlight_from_backbuf+=
if not tstree then return end

local root_node = tstree:root()
local root_start_row, _, root_end_row, _ = root_node:range()

-- Only worry about trees within the line range
if root_start_row > line or root_end_row < line then return end

local highlighter_query = self:get_query(lang[buf])

local state = {
  next_row = 0,
  iter = nil
}

if state.iter == nil then
  state.iter = highlighter_query:query():iter_captures(root_node, sources, line, root_end_row + 1)
end

while line >= state.next_row do
  local capture, node = state.iter()

  if capture == nil then break end

  local start_row, start_col, end_row, end_col = node:range()
  local hl = highlighter_query.hl_cache[capture]

  @shift_column_to_tangled

  if hl and start_row == line and end_row == line then
    vim.api.nvim_buf_set_extmark(buf, ns, tline, start_col,
                           { end_line = tline, end_col = end_col,
                             hl_group = hl,
                             ephemeral = true,
                             priority = 100 -- Low but leaves room below
                            })
  end
  if start_row > line then
    state.next_row = start_row
  end
end

@convert_line_number_to_untangled+=
local lookup = backlookup[buf]

@shift_column_to_tangled+=
start_col = start_col - indent
end_col = end_col - indent

@highlight_ntangle_lines+=
local curline = vim.api.nvim_buf_get_lines(buf, line, line+1, true)[1]

local linetype
@verify_if_section_or_reference
@decide_hl_group_with_linetype

vim.api.nvim_buf_set_extmark(buf, ns, line, 0, { 
    end_col = string.len(curline),
    hl_group = hl_group,
    ephemeral = true,
    priority = 100 -- Low but leaves room below
})

@highlight_line_test+=
local curline = vim.api.nvim_buf_get_lines(buf, line, line+1, true)[1]
vim.api.nvim_buf_set_extmark(buf, ns, line, 0, { 
    end_col = string.len(curline),
    hl_group = "Search",
    ephemeral = true,
    priority = 100 -- Low but leaves room below
})

@get_current_highlighter+=
local self = vim.treesitter.highlighter.active[buf]

@verify_if_section_or_reference+=
if string.match(curline, "^@[^@]%S*[+-]?=%s*$") then
  linetype = LineType.SECTION
elseif string.match(curline, "^%s*@[^@]%S*%s*$") then
  linetype = LineType.REFERENCE
elseif string.match(curline, "^##%S+$") then
  linetype = LineType.ASSEMBLY
end

@decide_hl_group_with_linetype+=
local hl_group
if linetype == LineType.REFERENCE then
  hl_group = "TSString"
elseif linetype == LineType.ASSEMBLY then
  hl_group = "TSString"
else
  hl_group = "TSAnnotation"
end
