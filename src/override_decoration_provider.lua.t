##ntangle-ts
@implement+=
function M.override()
  @get_treesitter_namespace
  @override_treesitter_decoration_provider
end

@script_variables+=
local highlighter = vim.treesitter.highlighter

@script_variables+=
local ns

@get_treesitter_namespace+=
local nss = vim.api.nvim_get_namespaces()
ns = nss["treesitter/highlighter"]

@override_treesitter_decoration_provider+=
print("override!")
vim.api.nvim_set_decoration_provider(ns, {
  on_buf = function(...) print("buf") highlighter._on_buf(...) end,
  on_line = M._on_line,
  on_win = function(...) print("wiwin") highlighter._on_win(...) end,
})
