##ntangle-ts
@implement+=
function M.attach()
  @get_current_buffer
  @return_if_already_attached

  local lookup = {}
  local bufs = {}


  @buffer_variables

  @init_incremental_tangling
  @update_line_number_untangled
  @fill_lookup_table
  @generate_tangled_code

  @fill_backbuf_if_not_done
  @create_parser_for_untangled
  @mutate_highlighter_for_ntangle
  @parse_everything_again

  vim.api.nvim_buf_attach(buf, true, {
    on_lines = function(_, _, _, firstline, lastline, new_lastline, _)
      @call_ntangle_incremental
      @update_line_number_untangled
      @fill_lookup_table
      @generate_tangled_code

      @parse_everything_again
    end
  })
end

@get_current_buffer+=
local buf = vim.api.nvim_get_current_buf()

@return_if_already_attached+=
if backbuf[buf] then
  return
end

@fill_backbuf_if_not_done+=
backbuf[buf] = true

@script_variables+=
local backlookup = {}
