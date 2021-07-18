##ntangle-ts-next
@script_variables+=
local linkedlist = {}

@implement+=
function linkedlist.push_back(list, el)
	@create_new_element
	if list.tail  then
		@add_element_to_tail
	else
		@add_first_element
	end
	@return_new_element
end

@create_new_element+=
local node = { data = el }

@add_element_to_tail+=
list.tail.next = node
node.prev = list.tail
list.tail = node

@add_first_element+=
list.tail  = node
list.head  = node

@implement+=
function linkedlist.push_front(list, el)
	@create_new_element
	if list.head then
		@add_element_to_head
	else
		@add_first_element
	end
	@return_new_element
end

@add_element_to_head+=
node.next = list.head
list.head.prev = node
list.head = node

@return_new_element+=
return node

@implement+=
function linkedlist.insert_after(list, it, el)
	@create_new_element
  if not it then
		@insert_el_in_head_after
  elseif it.next == nil then
		@insert_el_in_tail
	else
		@insert_el_in_between
	end
	@return_new_element
end

@insert_el_in_head_after+=
if not list then
  print(debug.traceback())
end
node.next = list.head
if list.head then
  list.head.prev = node
end
list.head = node

@insert_el_in_tail+=
it.next = node
node.prev = it
list.tail = node

@insert_el_in_between+=
node.next = it.next
node.prev = it
node.next.prev = node
it.next = node

@implement+=
function linkedlist.remove(list, it)
	if list.head == it then
		@remove_at_head
	elseif list.tail == it then
		@remove_at_tail
	else
		@remove_in_between
	end
end

@remove_at_head+=
if it.next then
	it.next.prev = nil
else
	list.tail = nil
end
list.head = list.head.next

@remove_at_tail+=
if it.prev then
	it.prev.next = nil
else
	list.head = nil
end
list.tail = list.tail.prev

@remove_in_between+=
it.prev.next = it.next
it.next.prev = it.prev

@implement+=
function linkedlist.get_size(list)
	local l = list.head
	local s = 0
	while l do
		l = l.next
		s = s + 1
	end
	return s
end

@implement+=
function linkedlist.iter_from(pos)
	return function ()
		local cur = pos
		if cur then 
			pos = pos.next
			return cur 
		end
	end
end

@implement+=
function linkedlist.iter(list)
	local pos = list.head
	return function ()
		local cur = pos
		if cur then 
			pos = pos.next
			return cur.data
		end
	end
end

@implement+=
function linkedlist.iter_from_back(pos)
	return function ()
		local cur = pos
		if cur then 
			pos = pos.prev
			return cur 
		end
	end
end

@implement+=
function linkedlist.insert_before(list, it, el)
	@create_new_element
	if it.prev == nil then
		@insert_el_in_head
	else
		@insert_el_in_between_before
	end
	@return_new_element
end

@insert_el_in_head+=
node.next = it
it.prev = node
list.head = node

@insert_el_in_between_before+=
it.prev.next = node
node.prev = it.prev
node.next = it
it.prev = node

@implement+=
function linkedlist.has_iter(list, it)
  local copy = list.head
  while copy do
    if copy == it then
      return true
    end
    copy = copy.next
  end
  return false
end
