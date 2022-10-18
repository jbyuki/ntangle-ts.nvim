##ntangle-ts
@implement+=
function M.attach()
  @check_that_not_disabled
  @override_if_not_done

  @get_current_buffer

  @get_language_extension

  @require_language
	@create_parser_for_buffer
	@create_highlighter_for_buffer


	-- @set_filetype_to_original_language
  @enable_filetype_indent

  @enable_conceal_reference_names
  -- @enable_foldexpr_for_ntangle

  local lookup = {}


  @buffer_variables
  @insert_line_function


  if buf_vars[bufname] then
    @restore_buffer_variables
  else
    @init_incremental_tangling
    @save_new_buffer_variables
  end


  @update_line_number_untangled
  @generate_tangled_code


  @fill_backbuf_if_not_done
  @save_buffer_language
  @mutate_highlighter_for_ntangle

  @parse_initial

  @fill_lookup_table
  @init_text_state
  @send_init_text_to_callbacks


  vim.api.nvim_buf_attach(buf, true, {
    on_bytes = function(...)
      local _, _, _, start_row, start_col, _, end_row, end_col, _, new_end_row, new_end_col, _ = unpack({...})
      @detach_if_told_so

      @do_text_transformation
      @correct_byte_range

      @call_ntangle_incremental
      @update_line_number_untangled
      @generate_tangled_code
      @parse_everything_again
      @fill_lookup_table

      @cancel_out_same_deinit_and_init_events
      @send_deinit_events_to_callbacks
      @send_init_events_to_callbacks
    end,
  })
end

@get_current_buffer+=
local buf = vim.api.nvim_get_current_buf()

@fill_backbuf_if_not_done+=
backbuf[buf] = true

@script_variables+=
local backlookup = {}
local buf_vars = {}
local buf_backup = {}

@buffer_variables+=
local bufname = string.lower(vim.api.nvim_buf_get_name(buf))

@save_new_buffer_variables+=
buf_vars[bufname] = {
  buf_asm = buf_asm,
  start_buf = start_buf,
  end_buf = end_buf,
}

@restore_buffer_variables+=
buf_asm = buf_vars[bufname].buf_asm
start_buf = buf_vars[bufname].start_buf
end_buf = buf_vars[bufname].end_buf

untangled_ll = asm_namespaces[buf_asm].untangled_ll
sections_ll = asm_namespaces[buf_asm].sections_ll
tangled_ll = asm_namespaces[buf_asm].tangled_ll
root_set = asm_namespaces[buf_asm].root_set
parts_ll = asm_namespaces[buf_asm].parts_ll

@init_bufs_set_buf_asm

@add_buf_sentinels_to_bufs_set

@save_buf_vars_for_parts+=
buf_vars[string.lower(origin_path)] = {
  buf_asm = buf_asm,
  start_buf = start_buf,
  end_buf = end_buf,
}

@script_variables+=
local overriden = false

@override_if_not_done+=
if not overriden then
  M.override()
  overriden = true
end

@enable_foldexpr_for_ntangle+=
vim.api.nvim_command [[setlocal foldmethod=expr]]
vim.api.nvim_command [[setlocal foldexpr=ntangle_ts#foldexpr()]]
vim.api.nvim_command [[setlocal fillchars=fold:\ ]]
vim.api.nvim_command [[setlocal foldtext=ntangle_ts#foldtext()]]

@correct_byte_range+=
local firstline = start_row
local lastline = start_row + end_row + 1
local new_lastline = start_row + new_end_row + 1
