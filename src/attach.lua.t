##ntangle-ts
@implement+=
function M.attach()
  @get_current_buffer
  @return_if_already_attached

  local lookup = {}
  local bufs = {}

  @tangle_to_table
  @fill_backbuf_if_not_done
  @create_parser_for_untangled
  @mutate_highlighter_for_ntangle
  @parse_everything_again
  @fill_backlookup_if_not_done

  vim.api.nvim_buf_attach(buf, true, {
    on_bytes = function(...)
      @tangle_to_table

      @parse_everything_again
      @fill_backlookup_if_not_done
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

@tangle_to_table+=
lookup = ntangle.tangle_to_table(bufs)

@fill_backbuf_if_not_done+=
backbuf[buf] = true

@script_variables+=
local backlookup = {}

@fill_backlookup_if_not_done+=
backlookup[buf] = lookup[fn]
