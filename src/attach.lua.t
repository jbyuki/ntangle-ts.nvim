##ntangle-ts
@script_variables+=
local valid = {}

@implement+=
function M.attach()
  @get_current_buffer
  @return_if_already_attached
  @remove_buffer_highlighter

  @unregister_any_callback_from_buffer_highlighter

  local lookup = {}
  local bufs = {}

  @tangle_to_buffer
  @fill_backbuf_if_not_done
  @fill_backlookup_if_not_done
  @if_no_highlighter_attached_to_buf_create

  valid[buf] = true

  vim.api.nvim_buf_attach(buf, true, {
    on_bytes = function(...)
      print("on bytes")
      valid[buf] = false
      vim.schedule(function()
        print("in schedule")
        @tangle_to_buffer
        valid[buf] = true
        @fill_backlookup_if_not_done
        @parse_everything_again
        @redraw_everything_that_was_postponed
      end)
    end
  })
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
lookup = ntangle.tangle_to_buf(bufs)

@fill_backbuf_if_not_done+=
for _, unbuf in pairs(bufs) do
  backbuf[buf] = unbuf
  print(unbuf)
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

@remove_buffer_highlighter+=
highlighter.active[buf] = nil

@unregister_any_callback_from_buffer_highlighter+=
local parser = vim.treesitter.get_parser()
parser._callbacks.changedtree = {}
parser._callbacks.bytes = {}

@parse_everything_again+=
parser:parse()
