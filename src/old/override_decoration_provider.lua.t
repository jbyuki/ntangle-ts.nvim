##ntangle-ts
@implement+=
function M.override()
  @get_treesitter_namespace
  @override_treesitter_decoration_provider
  @override_predicate_handlers
end

@script_variables+=
local highlighter = vim.treesitter.highlighter

@script_variables+=
local ns

@get_treesitter_namespace+=
local nss = vim.api.nvim_get_namespaces()
ns = nss["treesitter/highlighter"]

@override_treesitter_decoration_provider+=
vim.api.nvim_set_decoration_provider(ns, {
  on_buf = highlighter._on_buf,
  on_line = M._on_line,
  on_win = highlighter._on_win,
})

@override_predicate_handlers+=
local lua_match = function(match, _, source, predicate)
    local node = match[predicate[2]]
    local regex = predicate[3]
    local start_row, _, end_row, _ = node:range()
    if start_row ~= end_row then
      return false
    end

    return string.find(vim.treesitter.get_node_text(node, source), regex)
end

-- vim-match? and match? don't support string sources
vim.treesitter.add_predicate("vim-match?", lua_match, true)
vim.treesitter.add_predicate("match?", lua_match, true)
