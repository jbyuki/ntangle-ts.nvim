##ntangle-ts
@script_variables+=
local test_buf = vim.api.nvim_create_buf(false, true)
print("created test buf " .. test_buf)

@implement+=
function M._on_win(...)
  local _, _, buf, _ = unpack({...})
  if backbuf[buf] then
    return true
  else
    @if_not_tangle_default_to_on_win
  end
end

@if_not_tangle_default_to_on_win+=
highlighter._on_win(...)
