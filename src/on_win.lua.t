##ntangle-ts
@implement+=
function M._on_win(...)
  if backbuf[buf] then
    return true
  else
    @if_not_tangle_default_to_on_win
  end
end

@if_not_tangle_default_to_on_win+=
highlighter._on_win(...)
