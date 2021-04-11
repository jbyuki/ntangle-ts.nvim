##ntangle-ts
@implement+=
function M._on_line(...)
  local _, _, buf, line = unpack({...})
  @if_has_attach_override
  @otherwise_run_default_highlighter
end

@script_variables+=
local backbuf = {}

@if_has_attach_override+=
if backbuf[buf] then
  local unbuf = backbuf[buf]
  @get_highlighter
  @convert_line_number_to_untangled
  if lookup[line] then
    local tline = line
    local line = lookup[line]
    local self = hler
    @highlight_from_backbuf
  else
    @highlight_ntangle_lines
  end

@otherwise_run_default_highlighter+=
else
  highlighter._on_line(...)
end

@highlight_from_backbuf+=
self.tree:for_each_tree(function(tstree, tree)
  if not tstree then return end

  local root_node = tstree:root()
  local root_start_row, _, root_end_row, _ = root_node:range()

  -- Only worry about trees within the line range
  if root_start_row > line or root_end_row < line then return end

  local state = self:get_highlight_state(tstree)
  local highlighter_query = self:get_query(tree:lang())

  if state.iter == nil then
    state.iter = highlighter_query:query():iter_captures(root_node, self.bufnr, line, root_end_row + 1)
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
end, true)

@get_highlighter+=
local hler = highlighter.active[unbuf]

@convert_line_number_to_untangled+=
local lookup = backlookup[unbuf]
