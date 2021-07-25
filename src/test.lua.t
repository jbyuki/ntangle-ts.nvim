##test-ntangle-ts
@*=
local initial = {
  "@h=",
  "hello",
  "@a",
  "@a",
  "w",
  "@a+=",
  "hello",
}

local initial_state = {
  "hello",
  "hello",
  "hello",
  "w",
}

@check_function

@test_text_to_text
@test_text_to_ref
@test_text_to_sec
@test_ref_to_text
@test_ref_to_ref
@test_ref_to_section
@test_section_to_text
@test_section_to_ref
@test_section_to_section

@test_delete_last_line
@test_insert_last_line

print("Done.")

@do_changes_to_state+=
for _, change in ipairs(changes) do
  local off, del, ins, ins_text = unpack(change)
  ins_text = ins_text or ""
  local s1 = state:sub(1, off)
  local s2 = state:sub(off+del+1)
  state = s1 .. ins_text .. s2
end

@check_function+=
local function check(desc, fn, result) 
  @create_buf
  @set_initial_state
  @attach_to_api
  fn(buf)

  local state_lines = vim.split(state, "\n")
  local success = true
  if #state_lines ~= #result then
    print("line count mismatch")
    @display_both_states
    @display_buffer_content
    success = false
  else
    for i=1,#result do
      if state_lines[i] ~= result[i] then
        print("line mismatch")
        @display_both_states
        @display_buffer_content
        success = false
        break
      end
    end
  end

  if success then
    print(desc .. " OK!")
  else
    print(desc .. " FAIL!")
  end
end

@display_both_states+=
print("result:")
for i=1,#state_lines do
  print(i, state_lines[i])
end

print("expected:")
for i=1,#result do
  print(i, result[i])
end

print("buffer content:")
local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
for i=1,#lines do
  print(i, lines[i])
end


@create_buf+=
local buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_set_current_buf(buf)

@set_initial_state+=
vim.api.nvim_buf_set_lines(buf, 0, -1, true, initial)

@attach_to_api+=
local state = table.concat(initial_state, "\n") .. "\n"
require"ntangle-ts-next".attach(function(changes)
  @do_changes_to_state
end, false)

@test_text_to_text+=
check("text -> text", function(buf)
  vim.api.nvim_buf_set_text(buf, 1, 2, 1, 2, { "e" })
  vim.api.nvim_buf_set_text(0, 6, 1, 6, 1, { "a" })

end,
  {
    "heello",
    "haello",
    "haello",
    "w",
    "",
})

@test_text_to_ref+=
check("text -> ref", function(buf)
  vim.api.nvim_buf_set_text(0, 4, 0, 4, 1, { "a" })
  vim.api.nvim_buf_set_text(0, 4, 0, 4, 0, { "@" })

end,
  {
    "hello",
    "hello",
    "hello",
    "hello",
    "",
})

@test_text_to_sec+=
check("text -> section", function(buf)
  vim.api.nvim_buf_set_text(0, 3, 2, 3, 2, { "+" })
  vim.api.nvim_buf_set_text(0, 3, 3, 3, 3, { "=" })

end,
  {
    "hello",
    "w",
    "hello",
    "",
})

@test_ref_to_text+=
check("ref -> text", function(buf)
  vim.api.nvim_buf_set_text(0, 2, 0, 2, 1, { "" })

end,
  {
    "hello",
    "a",
    "hello",
    "w",
    "",
})

@test_ref_to_ref+=
check("ref -> ref", function(buf)
  vim.api.nvim_buf_set_text(0, 3, 1, 3, 2, { "b" })
  vim.api.nvim_buf_set_text(0, 3, 1, 3, 2, { "a" })

end,
  {
    "hello",
    "hello",
    "hello",
    "w",
    "",
})

@test_ref_to_section+=
check("ref -> section", function(buf)
  vim.api.nvim_buf_set_text(0, 3, 2, 3, 2, { "+=" })

end,
  {
    "hello",
    "w",
    "hello",
    "",
})

@test_section_to_text+=
check("section -> text", function(buf)
  vim.api.nvim_buf_set_text(0, 5, 0, 5, 1, { "" })

end,
  {
    "hello",
    "w",
    "a+=",
    "hello",
    "",
})

@test_section_to_ref+=
check("section -> ref", function(buf)
  vim.api.nvim_buf_set_text(0, 5, 3, 5, 4, { "" })

end,
  {
    "hello",
    "w",
    "hello",
    "",
})

@test_section_to_section+=
check("section -> section", function(buf)
  vim.api.nvim_buf_set_text(0, 3, 1, 3, 2, { "b" })
  vim.api.nvim_buf_set_text(0, 5, 1, 5, 2, { "b" })

end,
  {
    "hello",
    "hello",
    "w",
    "",
})

@test_delete_last_line+=
check("delete last line", function(buf)
  vim.api.nvim_buf_set_text(0, 5, 4, 6, 5, {})

end,
  {
    "hello",
    "w",
    "",
})
