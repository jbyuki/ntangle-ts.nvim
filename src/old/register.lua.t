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
  cbs(buf, root.filename,
    start_byte,old_byte,new_byte,
    start_row, start_col,
    old_row, old_end_col,
    new_row, new_end_col,
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
  @get_tangled_source_for_root_section
  @send_to_init_callbacks
end
init_events = {}

@get_tangled_source_for_root_section+=
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

@send_to_init_callbacks+=
for _, cbs in ipairs(cbs_init) do
  cbs(buf, root.filename, ext, source_lines)
end

@script_variables+=
local cbs_deinit = {}

@register_callbacks+=
if opts.on_deinit then
  table.insert(cbs_deinit, opts.on_deinit)
end

@script_variables+=
local init_events = {}

@append_to_init_event+=
init_events[l.str] = true

@send_init_events_to_callbacks+=
for name,_ in pairs(init_events) do
  local root = root_set[name]
  if root then
    @get_tangled_source_for_root_section
    @send_to_init_callbacks
  end
end
init_events = {}

@script_variables+=
local deinit_events = {}

@append_delete_root_section_event+=
local root = root_set[cur_delete.data.str]
if root and root.filename then
  deinit_events[root.filename] = true
end

@send_deinit_events_to_callbacks+=
for fn, _ in pairs(deinit_events) do
  for _, cbs in ipairs(cbs_deinit) do
    cbs(buf, fn, ext)
  end
end
deinit_events = {}

@cancel_out_same_deinit_and_init_events+=
local fns = vim.tbl_keys(init_events)
for _, name in ipairs(fns) do
  local root = root_set[name]
  if root then
    local fn = root.filename
    if deinit_events[fn] then
      init_events[name] = nil
      deinit_events[fn] = nil
    end
  end
end
