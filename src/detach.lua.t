##ntangle-ts
@implement+=
function M.detach()
  local buf = vim.api.nvim_get_current_buf()
  @detach_buf_attach
  @destroy_highlighter
  @detach_on_line_highlighter
end

@script_variables+=
local detach_this = {}

@detach_buf_attach+=
detach_this[buf] = true

@detach_if_told_so+=
if detach_this[buf] then
  detach_this[buf] = nil
  return true
end

@detach_on_line_highlighter+=
backbuf[buf] = nil

@destroy_highlighter+=
if hls[buf]  then
  hls[buf]:destroy()
  hls[buf] = nil
end
