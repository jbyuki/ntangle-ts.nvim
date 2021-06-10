##ntangle-ts
@script_variables+=
local cbs_change = {}

@implement+=
function M.register(opts)
  if opts and type(opts) == "table" then
    @register_callbacks
  end
end

@register_callbacks+=
if opts.on_change then
  table.insert(cbs_change, opts.on_change)
end

@send_to_cbs+=
for _, cbs in ipairs(cbs_change) do
  cbs(root.filename,
    start_byte,start_byte+old_byte,start_byte+new_byte,
    start_row, start_col,
    start_row+old_row, old_end_col,
    start_row+new_row, new_end_col,
    { it.data.line })
end

@script_variables+=
local cbs_init = {}

@register_callbacks+=
if opts.on_init then
  table.insert(cbs_init, opts.on_init)
end

@send_init_text_to_callbacks+=
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

  @send_to_init_callbacks
end

@send_to_init_callbacks+=
for _, cbs in ipairs(cbs_init) do
  cbs(root.filename, source_lines)
end
