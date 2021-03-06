##ntangle-ts
@parse_initial+=
for name, root in pairs(root_set) do
  local cur_tree, tree_changes = root.parser:parse(nil, root.sources)
  -- print("initial")
  -- print(vim.inspect(sources[buf]))
  -- print(cur_tree[1]:root():sexpr())
  root.tree = cur_tree
end

@parse_everything_again+=
for name, root in pairs(root_set) do
  local cur_tree, tree_changes = root.parser:parse(root.tree,root.sources)
  root.tree = cur_tree
end

@script_variables+=
local lang = {}

@save_buffer_language+=
lang[buf] = ext

@mutate_highlighter_for_ntangle+=
local local_parser = vim.treesitter.get_parser()
local_parser._callbacks.changedtree = {}
local_parser._callbacks.bytes = {}
