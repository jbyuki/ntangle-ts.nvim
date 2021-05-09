##../ntangle-ts
@insert_line_function+=
local insert_line = function(line, insert_after)
  @check_if_inserted_line_is_section
  @check_if_inserted_line_is_reference
  @check_if_inserted_line_is_assembly
  @otherwise_inserted_line_is_text

  return insert_after
end
