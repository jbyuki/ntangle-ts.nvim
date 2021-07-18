-- Generated using ntangle.nvim
local untangled = {}

local UNTANGLED = {
  CHAR = 1,

  SENTINEL = 2,

}

local ns_debug = vim.api.nvim_create_namespace("")

local linkedlist = {}

local LineType = {
	ASSEMBLY = 5,

	REFERENCE = 1,

	TEXT = 2,

	SECTION = 3,

}

local M = {}
function M.attach()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)

  local content = {}

  local text = table.concat(lines, "\n")
  for i=1,string.len(text) do
    local c = string.sub(text, i, i)

    local d = untangled.new("CHAR")
    d.sym = c

    linkedlist.push_back(content, d)

  end


  local cur = content.head
  local d = untangled.new("SENTINEL")

  if cur then
    linkedlist.insert_before(content, cur, d)
  else
    linkedlist.push_back(content, d)
  end

  while cur do
    if cur.data:is_newline() then
      local d = untangled.new("SENTINEL")
      linkedlist.insert_after(content, cur, d)

    end

    cur = cur.next
  end

  local ref_sizes = {}

  local deps = {}

  local mark_dirty
  mark_dirty = function(name, dirty) 
    if dirty[name] then
      return
    end

    dirty[name] = true
    if deps[name] then
      for d, _ in pairs(deps[name]) do
        mark_dirty(d, dirty)
      end
    end
  end

  local sections_ll = {}

  local roots = {}

  local cur = content.head
  assert(cur.data.type == UNTANGLED.SENTINEL, "First element in untangled must be a sentinel")
  while cur do
    local sentinel = cur
    cur = cur.next
    local line = ""
    local changed = false
    while cur do
      if cur.data:is_newline() then
        cur = cur.next
        break
      end

      if cur.data.type == UNTANGLED.CHAR and not cur.data.deleted then
        line = line .. cur.data.sym
      end

      if cur.data.deleted or cur.data.inserted then
        changed = true
      end
      cur = cur.next
    end

    local l = M.parse(line)
    if l.linetype == LineType.SECTION then
      local name, op = l.str, l.op
      sections_ll[name] = sections_ll[name] or {}

      local it
      if op == "-=" then
        it = linkedlist.push_front(sections_ll[name], sentinel)
      else
        it = linkedlist.push_back(sections_ll[name], sentinel)
      end
      sentinel.section = it

      if op == "=" then 
        roots[name] = {
          untangled = it,
          origin = origin,
        }
      end
    end

    sentinel.data.parsed = l

  end


  local compute_sizes
  compute_sizes = function(name) 
    if not sections_ll[name] then
      return 0
    end

    if ref_sizes[name] then
      return ref_sizes[name]
    end

    local size = 0
    for cur in linkedlist.iter(sections_ll[name]) do
      cur = cur.next
      while cur do
        while cur do
          if cur.data.type == UNTANGLED.SENTINEL then
            break
          end
          cur = cur.next
        end

        if not cur then break end
        local l = cur.data.parsed
        if l.linetype == LineType.TEXT then
          cur = cur.next
          local len = 0
          while cur do
            if cur.data.type == UNTANGLED.CHAR then
              len = len + string.len(cur.data.sym)
            elseif cur.data.type == UNTANGLED.SENTINEL then
              break
            end
            cur = cur.next
          end

          -- cur.data.len = len
          size = size + len

        elseif l.linetype == LineType.REFERENCE then
          local len = compute_sizes(l.str)
          cur.data.len = len
          size = size + len
          cur = cur.next

        elseif l.linetype == LineType.SECTION then
          break
        end

      end
    end
    ref_sizes[name] = size
    return size
  end

  for name, _ in pairs(roots) do
    compute_sizes(name)
  end

  local build_dep
  build_dep = function(name)
    if not sections_ll[name] then
      return
    end

    for cur in linkedlist.iter(sections_ll[name]) do
      cur = cur.next
      while cur do
        while cur do
          if cur.data.type == UNTANGLED.SENTINEL then
            break
          end
          cur = cur.next
        end

        if not cur then break end
        local l = cur.data.parsed
        if l.linetype == LineType.REFERENCE then
          deps[l.str] = deps[l.str] or {}
          deps[l.str][name] = true
          build_dep(l.str)


        elseif l.linetype == LineType.SECTION then
          break
        end

        cur = cur.next
      end
    end
  end

  for name, _ in pairs(roots) do
    build_dep(name)
  end


  local generate 
  generate = function(name, lines) 
    if not sections_ll[name] then
      return
    end

    for cur in linkedlist.iter(sections_ll[name]) do
      cur = cur.next
      while cur do
        while cur do
          if cur.data.type == UNTANGLED.SENTINEL then
            break
          end
          cur = cur.next
        end

        if not cur then break end
        local l = cur.data.parsed
        if l.linetype == LineType.TEXT then
          local line = ""
          local changed = false
          while cur do
            if cur.data:is_newline() then
              cur = cur.next
              break
            end

            if cur.data.type == UNTANGLED.CHAR and not cur.data.deleted then
              line = line .. cur.data.sym
            end

            if cur.data.deleted or cur.data.inserted then
              changed = true
            end
            cur = cur.next
          end

          table.insert(lines, line)

        elseif l.linetype == LineType.REFERENCE then
          generate(l.str, lines)
          cur = cur.next

        elseif l.linetype == LineType.SECTION then
          break
        end

      end
    end
  end

  for name, _ in pairs(roots) do
    local lines = {}
    generate(name, lines)
    -- @display_generated_lines
  end


  vim.api.nvim_buf_clear_namespace(0, ns_debug, 0, -1)

  local lnum = 0
  local cur = content.head
  while cur do
    local sentinel = cur
    cur = cur.next
    local line = ""
    local changed = false
    while cur do
      if cur.data:is_newline() then
        cur = cur.next
        break
      end

      if cur.data.type == UNTANGLED.CHAR and not cur.data.deleted then
        line = line .. cur.data.sym
      end

      if cur.data.deleted or cur.data.inserted then
        changed = true
      end
      cur = cur.next
    end

    local linetype = "UNKNOWN"
    local l = sentinel.data.parsed
    if l then
      if l.linetype == LineType.TEXT then
        linetype = "TEXT"
      elseif l.linetype == LineType.REFERENCE then
        linetype = "REF"
      elseif l.linetype == LineType.SECTION then
        linetype = "SECTION"
      end
    end
    vim.api.nvim_buf_set_extmark(0, ns_debug, lnum, 0, {
      virt_text = {{line, "NonText"}, {"[" .. linetype .. "]", "WarningMsg"}}
    })

    lnum = lnum + 1
  end


  local size_deleted
  size_deleted = function(name, deleted_ref) 
    if not sections_ll[name] then
      return 0
    end

    if deleted_ref[name] then
      return deleted_ref[name]
    end
    
    local size = 0
    for cur in linkedlist.iter(sections_ll[name]) do
      cur = cur.next
      while cur do
        while cur do
          if cur.data.type == UNTANGLED.SENTINEL then
            break
          end
          cur = cur.next
        end

        if not cur then break end
        local l = cur.data.parsed
        if l.linetype == LineType.TEXT then
          cur = cur.next
          local len = 0
          while cur do
            if cur.data.type == UNTANGLED.CHAR and not cur.data.inserted then
              len = len + string.len(cur.data.sym)
            elseif cur.data.type == UNTANGLED.SENTINEL then
              break
            end
            cur = cur.next
          end

          -- cur.data.len = len
          size = size + len

        elseif l.linetype == LineType.REFERENCE then
          local len = size_deleted(l.str)
          size = size + len
          cur = cur.next

        elseif l.linetype == LineType.SECTION then
          break
        end

      end
    end
    deleted_ref[name] = size
    return size
  end

  local size_inserted
  size_inserted = function(name, inserted_ref) 
    if not sections_ll[name] then
      return 0
    end

    if inserted_ref[name] then
      return inserted_ref[name]
    end
    
    local size = 0
    for cur in linkedlist.iter(sections_ll[name]) do
      cur = cur.next
      while cur do
        while cur do
          if cur.data.type == UNTANGLED.SENTINEL then
            break
          end
          cur = cur.next
        end

        if not cur then break end
        local l = cur.data.new_parsed or cur.data.parsed
        if l.linetype == LineType.TEXT then
          cur = cur.next
          local len = 0
          while cur do
            if cur.data.type == UNTANGLED.CHAR and not cur.data.deleted then
              len = len + string.len(cur.data.sym)
            elseif cur.data.type == UNTANGLED.SENTINEL then
              break
            end
            cur = cur.next
          end

          -- cur.data.len = len
          size = size + len

        elseif l.linetype == LineType.REFERENCE then
          local len = size_inserted(l.str)
          size = size + len
          cur = cur.next

        elseif l.linetype == LineType.SECTION then
          break
        end

      end
    end
    inserted_ref[name] = size
    return size
  end


  vim.api.nvim_buf_attach(0, true, {
    on_bytes = function(_, _, _, 
      start_row, start_col, start_byte, 
      old_row, old_col, old_byte, 
      new_row, new_col, new_byte)
      local cur = content.head
      local sentinel
      local section
      local cur_byte = 0
      while cur do
        if cur.data.type == UNTANGLED.CHAR then
          if cur_byte == start_byte then 
            break 
          end
          cur_byte = cur_byte + string.len(cur.data.sym)
        elseif cur.data.type == UNTANGLED.SENTINEL then
          sentinel = cur
          local l = sentinel.data.parsed
          if l.linetype == LineType.SECTION then
            section = l.str
          end

        end
        cur = cur.next
      end

      local start = cur

      local dirty = {}
      local to_delete = {}

      for i=1,old_byte do
        if not cur then
          break
        end
        cur.data.deleted = true
        table.insert(to_delete, cur)

        if section then
          mark_dirty(section, dirty)
        end


        while cur do
          cur = cur.next
          if cur.data.type == UNTANGLED.SENTINEL then
            sentinel = cur
            local l = sentinel.data.parsed
            if l.linetype == LineType.SECTION then
              section = l.str
            end

          end

          if cur.data.type == UNTANGLED.CHAR then
            break
          end
        end


      end


      local cur = start
      local to_insert = {}
      local lines = vim.api.nvim_buf_get_lines(0, start_row, start_row+new_row+1, true)
      lines[1] = string.sub(lines[1], start_col+1)
      lines[#lines] = string.sub(lines[#lines], 1, new_col)
      local text = table.concat(lines, "\n")

      local prev
      prev = cur.prev
      while cur do
        if not cur.data.deleted then
          break
        end
        prev = cur
        cur = cur.next
      end
      cur = prev

      local shifted = false
      if cur == start.prev then
        shifted = true
      end

      if section then
        mark_dirty(section, dirty)
      end


      for i=1,new_byte do
        local c = string.sub(text, i, i)
        local n = untangled.new("CHAR")
        n.sym = c
        n.inserted = true

        cur = linkedlist.insert_after(content, cur, n)
        table.insert(to_insert, cur)

        if i == 1 and shifted then
          start = cur
        end

      end


      local reparsed = {}

      local scan_changes
      scan_changes = function(name, offset, changes, start)
        if not sections_ll[name] then
          return
        end

        for cur in linkedlist.iter(sections_ll[name]) do
          cur = cur.next
          while cur do
            while cur do
              if cur.data.type == UNTANGLED.SENTINEL then
                break
              end
              cur = cur.next
            end

            if not cur then break end
            local l = cur.data.parsed
            if l.linetype == LineType.TEXT then
              local sentinel = cur
              local line = ""
              local changed = false
              while cur do
                if cur.data:is_newline() then
                  cur = cur.next
                  break
                end

                if cur.data.type == UNTANGLED.CHAR and not cur.data.deleted then
                  line = line .. cur.data.sym
                end

                if cur.data.deleted or cur.data.inserted then
                  changed = true
                end
                cur = cur.next
              end

              local new_l 
              if changed then
                new_l = M.parse(line)
              end


              if new_l then
                cur = sentinel
                if new_l.linetype == LineType.TEXT then
                  cur = cur.next
                  while cur do
                    if cur == start then
                      local deleted = 0
                      while cur do
                        if not cur.data.deleted then
                          break
                        end
                        deleted = deleted + 1
                        cur = cur.next
                      end

                      local inserted = 0
                      while cur do
                        if not cur.data.inserted then
                          break
                        end
                        inserted = inserted + 1
                        cur = cur.next
                      end

                      table.insert(changes, { offset, deleted, inserted })

                    end

                    if cur.data.type == UNTANGLED.CHAR then
                      if not cur.data.deleted then
                        offset = offset + 1
                      end
                    elseif cur.data.type == UNTANGLED.SENTINEL then
                      break
                    end
                    cur = cur.next
                  end

                elseif new_l.linetype == LineType.REFERENCE then
                end
              end

            elseif l.linetype == LineType.REFERENCE then
              local sentinel = cur
              cur = cur.next
              local line = ""
              local changed = false
              while cur do
                if cur.data:is_newline() then
                  cur = cur.next
                  break
                end

                if cur.data.type == UNTANGLED.CHAR and not cur.data.deleted then
                  line = line .. cur.data.sym
                end

                if cur.data.deleted or cur.data.inserted then
                  changed = true
                end
                cur = cur.next
              end

              local new_l 
              if changed then
                new_l = M.parse(line)
              end


              if new_l then
                if new_l.linetype == LineType.TEXT then
                  local deleted_ref = {}
                  local deleted = size_deleted(l.str, deleted_ref)

                  cur = sentinel
                  cur = cur.next
                  local len = 0
                  while cur do
                    if cur.data.type == UNTANGLED.CHAR and not cur.data.deleted then
                      len = len + string.len(cur.data.sym)
                    elseif cur.data.type == UNTANGLED.SENTINEL then
                      break
                    end
                    cur = cur.next
                  end

                  sentinel.data.new_parsed = new_l
                  table.insert(reparsed, sentinel)

                  table.insert(changes, { offset, deleted, len })

                  offset = offset + len
                elseif new_l.linetype == LineType.REFERENCE then
                  local new_ref = line:sub(2)
                  if l.str ~= new_ref then
                    local deleted_ref = {}
                    local deleted = size_deleted(l.str, deleted_ref)

                    local inserted_ref = {}
                    local inserted = size_inserted(new_ref, inserted_ref)

                    table.insert(changes, { offset, deleted, inserted })

                    l.str = new_ref
                  else
                    if dirty[l.str] then
                      offset = scan_changes(l.str, offset, changes, start)
                    else
                      if ref_sizes[l.str] then
                        offset = offset + ref_sizes[l.str]
                      end
                    end
                  end
                end
              end

            elseif l.linetype == LineType.SECTION then
              break
            end

          end
        end
        return offset
      end

      for name, _ in pairs(roots) do
        if dirty[name] then
          local changes = {}
          scan_changes(name, 0, changes, start)
          print("changes", vim.inspect(changes))
        end
      end


      for _, n in ipairs(to_delete) do
        linkedlist.remove(content, n)
      end

      for _, n in ipairs(to_insert) do
        n.data.inserted = nil
      end

      for _, n in ipairs(reparsed) do
        if n.data.new_parsed then
          n.data.parsed = n.data.new_parsed
          n.data.new_parsed = nil
        end
      end
      reparsed = {}

      for name, _ in pairs(dirty) do
        ref_sizes[name] = nil
      end

      for name, _ in pairs(roots) do
        if dirty[name] then
          compute_sizes(name)
        end
      end


      vim.api.nvim_buf_clear_namespace(0, ns_debug, 0, -1)

      local lnum = 0
      local cur = content.head
      while cur do
        local sentinel = cur
        cur = cur.next
        local line = ""
        local changed = false
        while cur do
          if cur.data:is_newline() then
            cur = cur.next
            break
          end

          if cur.data.type == UNTANGLED.CHAR and not cur.data.deleted then
            line = line .. cur.data.sym
          end

          if cur.data.deleted or cur.data.inserted then
            changed = true
          end
          cur = cur.next
        end

        local linetype = "UNKNOWN"
        local l = sentinel.data.parsed
        if l then
          if l.linetype == LineType.TEXT then
            linetype = "TEXT"
          elseif l.linetype == LineType.REFERENCE then
            linetype = "REF"
          elseif l.linetype == LineType.SECTION then
            linetype = "SECTION"
          end
        end
        vim.api.nvim_buf_set_extmark(0, ns_debug, lnum, 0, {
          virt_text = {{line, "NonText"}, {"[" .. linetype .. "]", "WarningMsg"}}
        })

        lnum = lnum + 1
      end

    end
  })
end

function untangled.new(t)
  local o = {
    ["type"] = UNTANGLED[t],
  }
  return setmetatable(o, { __index = untangled  })
end

function untangled:is_newline()
  return self.type == UNTANGLED.CHAR and self.sym == '\n'
end

function linkedlist.push_back(list, el)
	local node = { data = el }

	if list.tail  then
		list.tail.next = node
		node.prev = list.tail
		list.tail = node

	else
		list.tail  = node
		list.head  = node

	end
	return node

end

function linkedlist.push_front(list, el)
	local node = { data = el }

	if list.head then
		node.next = list.head
		list.head.prev = node
		list.head = node

	else
		list.tail  = node
		list.head  = node

	end
	return node

end

function linkedlist.insert_after(list, it, el)
	local node = { data = el }

  if not it then
		if not list then
		  print(debug.traceback())
		end
		node.next = list.head
		if list.head then
		  list.head.prev = node
		end
		list.head = node

  elseif it.next == nil then
		it.next = node
		node.prev = it
		list.tail = node

	else
		node.next = it.next
		node.prev = it
		node.next.prev = node
		it.next = node

	end
	return node

end

function linkedlist.remove(list, it)
	if list.head == it then
		if it.next then
			it.next.prev = nil
		else
			list.tail = nil
		end
		list.head = list.head.next

	elseif list.tail == it then
		if it.prev then
			it.prev.next = nil
		else
			list.head = nil
		end
		list.tail = list.tail.prev

	else
		it.prev.next = it.next
		it.next.prev = it.prev

	end
end

function linkedlist.get_size(list)
	local l = list.head
	local s = 0
	while l do
		l = l.next
		s = s + 1
	end
	return s
end

function linkedlist.iter_from(pos)
	return function ()
		local cur = pos
		if cur then 
			pos = pos.next
			return cur 
		end
	end
end

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

function linkedlist.iter_from_back(pos)
	return function ()
		local cur = pos
		if cur then 
			pos = pos.prev
			return cur 
		end
	end
end

function linkedlist.insert_before(list, it, el)
	local node = { data = el }

	if it.prev == nil then
		node.next = it
		it.prev = node
		list.head = node

	else
		it.prev.next = node
		node.prev = it.prev
		node.next = it
		it.prev = node

	end
	return node

end

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
function M.parse(line)
  local l = {}

  if string.match(line, "^%s*@@") then
    local _,_,pre,post = string.find(line, '^(.*)@@(.*)$')
    local text = pre .. "@" .. post
    l = { 
    	linetype = LineType.TEXT, 
      line = line,
    	str = text 
    }


  elseif string.match(line, "^@[^@]%S*[+-]?=%s*$") then
  	local _, _, name, op = string.find(line, "^@(%S-)([+-]?=)%s*$")

  	l = {
  	  linetype = LineType.SECTION,
  	  str = name,
  	  line = line,
  	  op = op,
  	}


  elseif string.match(line, "^%s*@[^@]%S*%s*$") then
    local _, _, prefix, name = string.find(line, "^(%s*)@(%S+)%s*$")

  	l = { 
  		linetype = LineType.REFERENCE, 
  		str = name,
  	  line = line,
  		prefix = prefix
  	}


  elseif string.match(line, "^##%S*%s*$") then
    l = {
      linetype = LineType.ASSEMBLY,
      line = line,
      str = asm,
    }


  else
  	l = { 
  		linetype = LineType.TEXT, 
  	  line = line,
  		str = line 
  	}

  end


  return l
end

function M.setup(opts)
end
return M
