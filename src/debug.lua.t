##ntangle-ts
@implement+=
function M.print_lookup()
  print("backlookup " .. vim.inspect(backlookup))
end

@display_tangle_output+=
print("TANGLED")
for line in linkedlist.iter(tangled_ll) do
  if line.linetype == LineType.TANGLED then
    print(line.line)
  end
end

@display_untangle_output+=
print("UNTANGLED")
for line in linkedlist.iter(untangled_ll) do
  print(getLinetype(line.linetype) .. " " .. vim.inspect(line.str))
end

@display_tangle_output_detail+=
for line in linkedlist.iter(tangled_ll) do
  print(getLinetype(line.linetype) .. " " .. vim.inspect(line.line))
end

@display_roots+=
print("ROOTS")
for name,_ in pairs(root_set) do
  print(name)
end
