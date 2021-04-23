##ntangle-ts
@implement+=
function M.attach()
  @get_current_buffer
  -- @return_if_already_attached

  @get_language_extension
  @require_language
	@create_parser_for_buffer
	@create_highlighter_for_buffer
	@set_filetype_to_original_language

  @enable_conceal_reference_names

  local lookup = {}

  @buffer_variables

  if buf_vars[bufname] then
    @restore_buffer_variables
  else
    @init_incremental_tangling
    @save_new_buffer_variables
  end

  @update_line_number_untangled
  @fill_lookup_table
  @generate_tangled_code

  @fill_backbuf_if_not_done
  @create_parser_for_untangled
  @mutate_highlighter_for_ntangle

  @parse_initial


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

@save_buf_vars_for_parts+=
buf_vars[string.lower(origin_path)] = {
  buf_asm = buf_asm,
  start_buf = start_buf,
  end_buf = end_buf,
}
