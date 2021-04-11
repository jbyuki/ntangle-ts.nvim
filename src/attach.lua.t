##ntangle-ts
@implement+=
function M.attach()
  @get_current_buffer
  @return_if_already_attached

  local lookup = {}
  local bufs = {}

  @tangle_to_buffer
  @fill_backbuf_if_not_done
  @fill_backlookup_if_not_done
  @if_no_highlighter_attached_to_buf_create

  -- vim.api.nvim_buf_attach(buf, true, {
    -- on_bytes = function(...)
      -- @tangle_to_buffer
    -- end
  -- })
end

@get_current_buffer+=
local buf = vim.api.nvim_get_current_buf()

@return_if_already_attached+=
if backbuf[buf] then
  return
end

@script_variables+=
local ntangle = require"ntangle"

@tangle_to_buffer+=
ntangle.tangle_to_buf(bufs, lookup)

@fill_backbuf_if_not_done+=
for _, unbuf in pairs(bufs) do
  backbuf[buf] = unbuf
end

@script_variables+=
local backlookup = {}

@fill_backlookup_if_not_done+=
for buf, l in pairs(lookup) do
  backlookup[buf] = l
end

@if_no_highlighter_attached_to_buf_create+=
local ft = vim.api.nvim_buf_get_option(buf, "ft")
local parser = vim.treesitter.get_parser(backbuf[buf], ft)
highlighter.new(parser)
