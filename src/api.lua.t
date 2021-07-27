##ntangle-ts-next
@pass_changes_to_callback+=
if callback then
  callback(changes)
end

@implement+=
function M.get_roots()
  return vim.tbl_keys(roots)
end
