##ntangle-ts
@require_language+=
if not vim._ts_has_language(ext) then
  local fname = 'parser/' .. ext .. '.*'
  local paths = vim.api.nvim_get_runtime_file(fname, false)

  if #paths == 0 then
    error("no parser for '"..ext.."' language, see :help treesitter-parsers")
  end

  local path = paths[1]
  vim.schedule(function() print("loading " .. path) end)

  -- pcall(function() vim._ts_add_language(path, ext) end)
  vim._ts_add_language(path, ext)
end
