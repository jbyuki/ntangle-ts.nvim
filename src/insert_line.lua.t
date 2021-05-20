##ntangle-ts
@insert_line_function+=
local insert_line
insert_line = function(i, line, start_buf, end_buf, insert_after)
  @check_if_inserted_line_is_section
  @check_if_inserted_line_is_reference
  @check_if_inserted_line_is_assembly
  @otherwise_inserted_line_is_text

  return start_buf, end_buf, insert_after
end
