##ntangle-ts
@script_variables+=
local enabled = true

@implement+=
function M.enable()
  enabled = true
end

function M.disable()
  enabled = false
end

@check_that_not_disabled+=
if not enabled then
  return
end
