-- Generated using ntangle.nvim
local untangled = {}

local UNTANGLED = {
  CHAR = 1,

  SENTINEL = 2,

}

local ns_debug = vim.api.nvim_create_namespace("")

local internal_buf

local linkedlist = {}

local LineType = {
	EMPTY = 6,

	ASSEMBLY = 5,

	REFERENCE = 1,

	TEXT = 2,

	SECTION = 3,

}

local playground_text = ""
local playground_buf

local M = {}
function M.attach(callback, show_playground)
  if show_playground == nil then show_playground = true end

  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)

  local content = {}

  local text = table.concat(lines, "\n") .. "\n"
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
    if cur.data:is_newline() and cur.next then
      local d = untangled.new("SENTINEL")
      cur = linkedlist.insert_after(content, cur, d)

    end

    cur = cur.next
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
    local empty = true
    while cur do
      if cur.data.deleted or cur.data.inserted then
        changed = true
      end

      if cur.data:is_newline() and not cur.data.deleted then
        cur = cur.next
        empty = false
        break
      end

      if cur.data.type == UNTANGLED.CHAR and not cur.data.deleted then
        empty = false
        line = line .. cur.data.sym
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
      sentinel.data.section = it

      if op == "=" then 
        roots[name] = {
          untangled = it,
          origin = origin,
        }
      end
    end

    sentinel.data.parsed = l

  end


  local cur = content.head
  local sentinel = cur
  cur = cur.next
  local virtual
  do 
    local l = sentinel.data.parsed
    if l.linetype == LineType.TEXT then
      virtual = false
    else
      virtual = true
    end
  end

  while cur do
    if cur.data.type == UNTANGLED.CHAR then
      cur.data.virtual = virtual
    elseif cur.data.type == UNTANGLED.SENTINEL then
      sentinel = cur
      do 
        local l = sentinel.data.parsed
        if l.linetype == LineType.TEXT then
          virtual = false
        else
          virtual = true
        end
      end

    end
    cur = cur.next
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
          local empty = true
          while cur do
            if cur.data.deleted or cur.data.inserted then
              changed = true
            end

            if cur.data:is_newline() and not cur.data.deleted then
              cur = cur.next
              empty = false
              break
            end

            if cur.data.type == UNTANGLED.CHAR and not cur.data.deleted then
              empty = false
              line = line .. cur.data.sym
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
    if show_playground then
      local old_win = vim.api.nvim_get_current_win()
      vim.cmd [[sp]]

      playground_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_current_buf(playground_buf)
      vim.api.nvim_set_current_win(old_win)

      playground_text = ""
      for _, line in ipairs(lines) do
        playground_text = playground_text .. line .. "\n"
      end

      local playground_lines = vim.split(playground_text, "\n")
      vim.api.nvim_buf_set_lines(playground_buf, 0, -1, true, playground_lines)


      local old_win = vim.api.nvim_get_current_win()
      vim.cmd [[sp]]

      internal_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_current_buf(internal_buf)
      vim.api.nvim_set_current_win(old_win)

      local lines = {}
      local single_line = {}
      for data in linkedlist.iter(content) do
        if data.type == UNTANGLED.CHAR then
          table.insert(single_line, "CHAR " .. vim.inspect(data.sym) .. " " .. M.get_virtual(data.virtual))
        elseif data.type == UNTANGLED.SENTINEL then
          if #single_line > 0 then
            table.insert(lines, table.concat(single_line, " "))
            single_line = {}
          end

          table.insert(lines, "SENTINEL " .. M.get_linetype(data.parsed.linetype))
        end
      end

      if single_line ~= "" then
        table.insert(lines, table.concat(single_line, " "))
      end

      vim.api.nvim_buf_set_lines(internal_buf, 0, -1, true, lines)

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
    local empty = true
    while cur do
      if cur.data.deleted or cur.data.inserted then
        changed = true
      end

      if cur.data:is_newline() and not cur.data.deleted then
        cur = cur.next
        empty = false
        break
      end

      if cur.data.type == UNTANGLED.CHAR and not cur.data.deleted then
        empty = false
        line = line .. cur.data.sym
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


  local size_inserted

  local size_deleted

  local size_inserted_from

  local size_deleted_from

  local scan_changes
  scan_changes = function(name, offset, changes)
    if not sections_ll[name] then
      return offset
    end

    for cur in linkedlist.iter(sections_ll[name]) do
      local sec = cur
      cur = cur.next
      local skip_part = false
      if sec.data.deleted == name then
        local size = 0
        local cur = sec
        cur = cur.next
        local inserted_ref = {}
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
            local inserted = ""
            while cur do
              if cur.data.type == UNTANGLED.CHAR and not cur.data.deleted then
                inserted = inserted .. cur.data.sym
              elseif cur.data.type == UNTANGLED.SENTINEL then
                break
              end
              cur = cur.next
            end

            size = size + string.len(inserted)
          elseif l.linetype == LineType.REFERENCE then
            size = size + size_inserted(l.str, inserted_ref)
          elseif l.linetype == LineType.EMPTY then
            cur = cur.next
          elseif l.linetype == LineType.SECTION then
            break
          end

        end

        if size > 0 then
          table.insert(changes, { offset, size, 0 })
        end

        skip_part = true
      elseif sec.data.inserted == name then
        cur = cur.next
        local inserted_ref = {}
        local inserted = size_inserted_from(cur, inserted_ref)

        if string.len(inserted) > 0 then
          table.insert(changes, { offset, 0, string.len(inserted), inserted })
        end

        offset = offset + string.len(inserted)
        skip_part = true
      end

      if not skip_part then
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
            local new_l = sentinel.data.new_parsed
            cur = cur.next

            if new_l then
              cur = sentinel
              if new_l.linetype == LineType.TEXT then
                cur = cur.next
                while cur do
                  if cur.data.type == UNTANGLED.CHAR then
                    if cur.data.deleted or cur.data.inserted or cur.data.virtual then
                      local inserted = ""
                      local deleted = 0
                      while cur do
                        if cur.data.type == UNTANGLED.CHAR then
                          if cur.data.deleted then
                            deleted = deleted + 1
                          elseif cur.data.inserted or cur.data.virtual then
                            inserted = inserted .. cur.data.sym
                          else
                            break
                          end
                        elseif cur.data.type == UNTANGLED.SENTINEL then
                          break
                        end
                        cur = cur.next
                      end

                      table.insert(changes, { offset, deleted, string.len(inserted), inserted })

                      offset = offset + string.len(inserted)
                      if cur and cur.data.type == UNTANGLED.SENTINEL then
                        break
                      end
                    else
                      if not cur.data.deleted then
                        offset = offset + 1
                      end
                      cur = cur.next
                    end
                  elseif cur and cur.data.type == UNTANGLED.SENTINEL then
                    break
                  end
                end

              elseif new_l.linetype == LineType.REFERENCE then
                local inserted_ref = {}
                local inserted = size_inserted(new_l.str, inserted_ref)

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

                table.insert(changes, { offset, len, string.len(inserted), inserted })

              elseif new_l.linetype == LineType.SECTION then
                local deleted_ref = {}
                local len = size_deleted_from(sentinel, deleted_ref)

                table.insert(changes, { offset, len, 0 })

                break
              elseif new_l.linetype == LineType.EMPTY then
                cur = cur.next
                while cur do
                  if cur.data.type == UNTANGLED.CHAR then
                    if cur.data.deleted or cur.data.inserted or cur.data.virtual then
                      local inserted = ""
                      local deleted = 0
                      while cur do
                        if cur.data.type == UNTANGLED.CHAR then
                          if cur.data.deleted then
                            deleted = deleted + 1
                          elseif cur.data.inserted or cur.data.virtual then
                            inserted = inserted .. cur.data.sym
                          else
                            break
                          end
                        elseif cur.data.type == UNTANGLED.SENTINEL then
                          break
                        end
                        cur = cur.next
                      end

                      table.insert(changes, { offset, deleted, string.len(inserted), inserted })

                      offset = offset + string.len(inserted)
                      if cur and cur.data.type == UNTANGLED.SENTINEL then
                        break
                      end
                    else
                      if not cur.data.deleted then
                        offset = offset + 1
                      end
                      cur = cur.next
                    end
                  elseif cur and cur.data.type == UNTANGLED.SENTINEL then
                    break
                  end
                end

              end
            else
              cur = sentinel
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

              offset = offset + len
            end

          elseif l.linetype == LineType.REFERENCE then
            local sentinel = cur
            local new_l = sentinel.data.new_parsed
            cur = cur.next

            if new_l then
              if new_l.linetype == LineType.TEXT then
                local deleted_ref = {}
                local deleted = size_deleted(l.str, deleted_ref)

                cur = sentinel
                cur = cur.next
                local inserted = ""
                while cur do
                  if cur.data.type == UNTANGLED.CHAR and not cur.data.deleted then
                    inserted = inserted .. cur.data.sym
                  elseif cur.data.type == UNTANGLED.SENTINEL then
                    break
                  end
                  cur = cur.next
                end

                table.insert(changes, { offset, deleted, string.len(inserted), inserted })

                offset = offset + string.len(inserted)
              elseif new_l.linetype == LineType.REFERENCE then
                local deleted_ref = {}
                local deleted = size_deleted(l.str, deleted_ref)

                local inserted_ref = {}
                local inserted = size_inserted(new_l.str, inserted_ref)

                table.insert(changes, { offset, deleted, string.len(inserted), inserted })

                l.str = new_ref
              elseif new_l.linetype == LineType.SECTION then
                local deleted_ref = {}
                local len = size_deleted_from(sentinel, deleted_ref)

                table.insert(changes, { offset, len, 0 })

                break
              elseif new_l.linetype == LineType.EMPTY then
                local deleted_ref = {}
                local deleted = size_deleted(l.str, deleted_ref)

                table.insert(changes, { offset, deleted, 0 })

                cur = cur.next
              end
            else
              offset = scan_changes(l.str, offset, changes)
            end

          elseif l.linetype == LineType.EMPTY then
            local new_l = cur.data.new_parsed
            if new_l.linetype == LineType.TEXT then
              cur = cur.next
              while cur do
                if cur.data.type == UNTANGLED.CHAR then
                  if cur.data.deleted or cur.data.inserted or cur.data.virtual then
                    local inserted = ""
                    local deleted = 0
                    while cur do
                      if cur.data.type == UNTANGLED.CHAR then
                        if cur.data.deleted then
                          deleted = deleted + 1
                        elseif cur.data.inserted or cur.data.virtual then
                          inserted = inserted .. cur.data.sym
                        else
                          break
                        end
                      elseif cur.data.type == UNTANGLED.SENTINEL then
                        break
                      end
                      cur = cur.next
                    end

                    table.insert(changes, { offset, deleted, string.len(inserted), inserted })

                    offset = offset + string.len(inserted)
                    if cur and cur.data.type == UNTANGLED.SENTINEL then
                      break
                    end
                  else
                    if not cur.data.deleted then
                      offset = offset + 1
                    end
                    cur = cur.next
                  end
                elseif cur and cur.data.type == UNTANGLED.SENTINEL then
                  break
                end
              end

            elseif new_l.linetype == LineType.REFERENCE then
              local inserted_ref = {}
              local inserted = size_inserted(new_l.str, inserted_ref)

              table.insert(changes, { offset, 0, string.len(inserted), inserted })

              cur = cur.next
            elseif new_l.linetype == LineType.SECTION then
              break
            end

          elseif l.linetype == LineType.SECTION then
            if cur.data.deleted and not cur.data.inserted then
              local new_l = cur.data.new_parsed
              local inserted_ref = {}
              local inserted = size_inserted_from(cur, inserted_ref)
              if string.len(inserted) > 0 then
                table.insert(changes, { offset, 0, string.len(inserted), inserted })
                offset = offset + string.len(inserted)
              end

            end
            break
          end

        end
      end
    end
    return offset
  end

  size_deleted_from = function(cur, deleted_ref)
    local size = 0
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
        local len = size_deleted(l.str, deleted_ref)
        size = size + len
        cur = cur.next

      elseif l.linetype == LineType.EMPTY then
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

        size = size + len

      elseif l.linetype == LineType.SECTION then
        break
      end

    end
    return size
  end

  size_inserted_from = function(cur, inserted_ref)
    local content = ""
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
        local inserted = ""
        while cur do
          if cur.data.type == UNTANGLED.CHAR and not cur.data.deleted then
            inserted = inserted .. cur.data.sym
          elseif cur.data.type == UNTANGLED.SENTINEL then
            if cur.data.new_parsed and cur.data.new_parsed.linetype == LineType.EMPTY then
            else
              break
            end
          end
          cur = cur.next
        end

        content = content .. inserted

      elseif l.linetype == LineType.REFERENCE then
        local inserted_ref = {}
        local inserted = size_inserted(l.str, inserted_ref)
        content = content .. inserted
        cur = cur.next

      elseif l.linetype == LineType.EMPTY then
        cur = cur.next
        while cur do
          if cur.data.type == UNTANGLED.SENTINEL then
            break
          end
          cur = cur.next
        end


      elseif l.linetype == LineType.SECTION then
        break
      end

    end
    return content
  end

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
      size = size + size_deleted_from(cur, deleted_ref)
    end
    deleted_ref[name] = size
    return size
  end

  size_inserted = function(name, inserted_ref) 
    if not sections_ll[name] then
      return ""
    end

    if inserted_ref[name] then
      return inserted_ref[name]
    end
    
    local content = ""
    for cur in linkedlist.iter(sections_ll[name]) do
      if not cur.data.deleted or cur.data.deleted ~= name then
        cur = cur.next
        content = content .. size_inserted_from(cur, inserted_ref)
      end
    end
    inserted_ref[name] = content
    return content
  end


  vim.api.nvim_buf_attach(0, true, {
    on_bytes = function(_, _, _, 
      start_row, start_col, start_byte, 
      old_row, old_col, old_byte, 
      new_row, new_col, new_byte)
      local front_sections = {}
      local back_sections = {}
      local cur = content.head
      local sentinel
      local section
      local cur_byte = 0
      local cur_section, prev_section
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

          if l.linetype == LineType.SECTION then
            if l.op == "-=" then
              front_sections[l.str] = sentinel.data.section
            else
              back_sections[l.str] = sentinel.data.section
            end
            prev_section = cur_section
            cur_section = sentinel
          end

        end
        cur = cur.next
      end

      local start_sentinel = sentinel
      local reparsed = {}
      local to_insert = {}

      local start = cur

      local to_delete = {}

      for i=1,old_byte do
        if not cur then
          break
        end
        if sentinel then
          reparsed[sentinel] = true
        end

        cur.data.deleted = true
        table.insert(to_delete, cur)

        while cur.next do
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

      if new_byte > 0 then
        local cur = start
        sentinel = start_sentinel
        local lines = vim.api.nvim_buf_get_lines(0, start_row, start_row+new_row+1, false)
        lines[1] = string.sub(lines[1], start_col+1)
        lines[#lines] = string.sub(lines[#lines], 1, new_col)
        if #lines < new_row+1 then
          table.insert(lines, "")
        end

        local text = table.concat(lines, "\n")

        local prev
        if cur then
          prev = cur.prev
        end

        while cur do
          if not cur.data.deleted then
            break
          end
          prev = cur
          cur = cur.next
        end
        cur = prev

        local shifted = false
        if start and cur == start.prev then
          shifted = true
        end

        if not cur then
          cur = content.tail.prev
          shifted = true
        end

        if sentinel then
          reparsed[sentinel] = true
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

      end

      local new_reparsed = {}
      for cur, _ in pairs(reparsed) do
        local sentinel = cur
        cur = cur.next
        while cur do
          if cur.data.type == UNTANGLED.CHAR then
            if cur.data.sym == "\n" then
              -- d d d d i i i i
              if cur.data.inserted then
                local s = untangled.new("SENTINEL")
                s.parsed = {
                  linetype = LineType.EMPTY,
                }
                local n = linkedlist.insert_after(content, cur, s)
                new_reparsed[n] = true

              elseif cur.data.deleted then
                if cur.next then
                  local n = cur.next
                  if n.data.type == UNTANGLED.SENTINEL then
                    n.data.new_parsed = {
                      linetype = LineType.EMPTY,
                    }
                    new_reparsed[n] = true
                    break
                  end
                end
              end

            end
          elseif cur.data.type == UNTANGLED.SENTINEL then
            break
          end
          cur = cur.next
        end

      end

      for cur, _ in pairs(new_reparsed) do
        reparsed[cur] = true
      end


      for cur, _ in pairs(reparsed) do
        local sentinel = cur
        if not sentinel.data.new_parsed then
          local line = ""
          local changed = false
          local empty = true
          while cur do
            if cur.data.deleted or cur.data.inserted then
              changed = true
            end

            if cur.data:is_newline() and not cur.data.deleted then
              cur = cur.next
              empty = false
              break
            end

            if cur.data.type == UNTANGLED.CHAR and not cur.data.deleted then
              empty = false
              line = line .. cur.data.sym
            end
            cur = cur.next
          end

          local l = sentinel.data.parsed
          local new_l
          if empty then
            new_l = {
              linetype = LineType.EMPTY,
            }
          else
            new_l = M.parse(line)
          end

          sentinel.data.new_parsed = new_l

        end
      end

      for n, _ in pairs(reparsed) do
        local sentinel = n
        if sentinel.data.parsed.linetype == LineType.REFERENCE or sentinel.data.parsed.linetype == LineType.SECTION then
          local cur = sentinel.next
          while cur do
            if cur.data.type == UNTANGLED.CHAR then
              if not cur.data.virtual then
                cur.data.deleted = true
              end

            elseif cur.data.type == UNTANGLED.SENTINEL then
              if cur.data.new_parsed and cur.data.new_parsed.linetype == LineType.EMPTY then
              else
                break
              end
            end
            cur = cur.next
          end
        end
      end


      for cur, _ in pairs(reparsed) do
        local sentinel = cur
        local l = cur.data.parsed
        local new_l = cur.data.new_parsed
        if new_l then
          if l.linetype == LineType.SECTION then
            if new_l.linetype == LineType.SECTION then
              if new_l.str ~= l.str then
                sentinel.data.deleted = l.str

                sentinel.data.inserted = new_l.str
                if not sections_ll[new_l.str] then
                  sections_ll[new_l.str] = {}
                  local it = linkedlist.push_back(sections_ll[new_l.str], sentinel)
                  sentinel.data.new_section = it
                else
                  if new_l.op == "-=" then
                    if front_sections[new_l.str] then
                      local it = linkedlist.insert_before(sections_ll[new_l.str], front_sections[new_l.str], sentinel)
                      sentinel.data.new_section = it
                    else
                      local added = false
                      local part = sections_ll[new_l.str].head
                      while part do
                        local section_sentinel = part.data
                        local l = section_sentinel.data.parsed
                        if l.op == "+=" then
                          local it = linkedlist.insert_before(sections_ll[new_l.str], part, sentinel)
                          sentinel.data.new_section = it
                          added = true
                          break
                        end
                        part = part.next
                      end

                      if not added then
                        local it = linkedlist.push_back(sections_ll[new_l.str], sentinel)
                        sentinel.data.new_section = it
                      end

                    end
                  else
                    if back_sections[new_l.str] then
                      local it = linkedlist.insert_after(sections_ll[new_l.str], back_sections[new_l.str], sentinel)
                      sentinel.data.new_section = it
                    else
                      local added = false
                      local part = sections_ll[new_l.str].head
                      while part do
                        local section_sentinel = part.data
                        local l = section_sentinel.data.parsed
                        if l.op == "+=" then
                          local it = linkedlist.insert_before(sections_ll[new_l.str], part, sentinel)
                          sentinel.data.new_section = it
                          added = true
                          break
                        end
                        part = part.next
                      end

                      if not added then
                        local it = linkedlist.push_back(sections_ll[new_l.str], sentinel)
                        sentinel.data.new_section = it
                      end

                    end
                  end
                end

              end
            elseif new_l.linetype == LineType.TEXT then
              sentinel.data.deleted = l.str

            elseif new_l.linetype == LineType.REFERENCE then
              sentinel.data.deleted = l.str

            elseif new_l.linetype == LineType.EMPTY then
              sentinel.data.deleted = l.str

            end
          elseif l.linetype == LineType.TEXT then
            if new_l.linetype == LineType.SECTION then
              sentinel.data.inserted = new_l.str
              if not sections_ll[new_l.str] then
                sections_ll[new_l.str] = {}
                local it = linkedlist.push_back(sections_ll[new_l.str], sentinel)
                sentinel.data.new_section = it
              else
                if new_l.op == "-=" then
                  if front_sections[new_l.str] then
                    local it = linkedlist.insert_before(sections_ll[new_l.str], front_sections[new_l.str], sentinel)
                    sentinel.data.new_section = it
                  else
                    local added = false
                    local part = sections_ll[new_l.str].head
                    while part do
                      local section_sentinel = part.data
                      local l = section_sentinel.data.parsed
                      if l.op == "+=" then
                        local it = linkedlist.insert_before(sections_ll[new_l.str], part, sentinel)
                        sentinel.data.new_section = it
                        added = true
                        break
                      end
                      part = part.next
                    end

                    if not added then
                      local it = linkedlist.push_back(sections_ll[new_l.str], sentinel)
                      sentinel.data.new_section = it
                    end

                  end
                else
                  if back_sections[new_l.str] then
                    local it = linkedlist.insert_after(sections_ll[new_l.str], back_sections[new_l.str], sentinel)
                    sentinel.data.new_section = it
                  else
                    local added = false
                    local part = sections_ll[new_l.str].head
                    while part do
                      local section_sentinel = part.data
                      local l = section_sentinel.data.parsed
                      if l.op == "+=" then
                        local it = linkedlist.insert_before(sections_ll[new_l.str], part, sentinel)
                        sentinel.data.new_section = it
                        added = true
                        break
                      end
                      part = part.next
                    end

                    if not added then
                      local it = linkedlist.push_back(sections_ll[new_l.str], sentinel)
                      sentinel.data.new_section = it
                    end

                  end
                end
              end

            end
          elseif  l.linetype == LineType.REFERENCE then
            if new_l.linetype == LineType.SECTION then
              sentinel.data.inserted = new_l.str
              if not sections_ll[new_l.str] then
                sections_ll[new_l.str] = {}
                local it = linkedlist.push_back(sections_ll[new_l.str], sentinel)
                sentinel.data.new_section = it
              else
                if new_l.op == "-=" then
                  if front_sections[new_l.str] then
                    local it = linkedlist.insert_before(sections_ll[new_l.str], front_sections[new_l.str], sentinel)
                    sentinel.data.new_section = it
                  else
                    local added = false
                    local part = sections_ll[new_l.str].head
                    while part do
                      local section_sentinel = part.data
                      local l = section_sentinel.data.parsed
                      if l.op == "+=" then
                        local it = linkedlist.insert_before(sections_ll[new_l.str], part, sentinel)
                        sentinel.data.new_section = it
                        added = true
                        break
                      end
                      part = part.next
                    end

                    if not added then
                      local it = linkedlist.push_back(sections_ll[new_l.str], sentinel)
                      sentinel.data.new_section = it
                    end

                  end
                else
                  if back_sections[new_l.str] then
                    local it = linkedlist.insert_after(sections_ll[new_l.str], back_sections[new_l.str], sentinel)
                    sentinel.data.new_section = it
                  else
                    local added = false
                    local part = sections_ll[new_l.str].head
                    while part do
                      local section_sentinel = part.data
                      local l = section_sentinel.data.parsed
                      if l.op == "+=" then
                        local it = linkedlist.insert_before(sections_ll[new_l.str], part, sentinel)
                        sentinel.data.new_section = it
                        added = true
                        break
                      end
                      part = part.next
                    end

                    if not added then
                      local it = linkedlist.push_back(sections_ll[new_l.str], sentinel)
                      sentinel.data.new_section = it
                    end

                  end
                end
              end

            end
          elseif l.linetype == LineType.EMPTY then
            if new_l.linetype == LineType.SECTION then
              sentinel.data.inserted = new_l.str
              if not sections_ll[new_l.str] then
                sections_ll[new_l.str] = {}
                local it = linkedlist.push_back(sections_ll[new_l.str], sentinel)
                sentinel.data.new_section = it
              else
                if new_l.op == "-=" then
                  if front_sections[new_l.str] then
                    local it = linkedlist.insert_before(sections_ll[new_l.str], front_sections[new_l.str], sentinel)
                    sentinel.data.new_section = it
                  else
                    local added = false
                    local part = sections_ll[new_l.str].head
                    while part do
                      local section_sentinel = part.data
                      local l = section_sentinel.data.parsed
                      if l.op == "+=" then
                        local it = linkedlist.insert_before(sections_ll[new_l.str], part, sentinel)
                        sentinel.data.new_section = it
                        added = true
                        break
                      end
                      part = part.next
                    end

                    if not added then
                      local it = linkedlist.push_back(sections_ll[new_l.str], sentinel)
                      sentinel.data.new_section = it
                    end

                  end
                else
                  if back_sections[new_l.str] then
                    local it = linkedlist.insert_after(sections_ll[new_l.str], back_sections[new_l.str], sentinel)
                    sentinel.data.new_section = it
                  else
                    local added = false
                    local part = sections_ll[new_l.str].head
                    while part do
                      local section_sentinel = part.data
                      local l = section_sentinel.data.parsed
                      if l.op == "+=" then
                        local it = linkedlist.insert_before(sections_ll[new_l.str], part, sentinel)
                        sentinel.data.new_section = it
                        added = true
                        break
                      end
                      part = part.next
                    end

                    if not added then
                      local it = linkedlist.push_back(sections_ll[new_l.str], sentinel)
                      sentinel.data.new_section = it
                    end

                  end
                end
              end

            end
          end
        end
      end

      local changes = {}
      for name, _ in pairs(roots) do
        scan_changes(name, 0, changes)
      end
      if show_playground then
        print("changes", vim.inspect(changes))
      end


      for _, n in ipairs(to_delete) do
        linkedlist.remove(content, n)
      end

      for _, n in ipairs(to_insert) do
        n.data.inserted = nil
      end

      for cur, _ in pairs(reparsed) do
        local sentinel = cur
        local l = sentinel.data.parsed
        local new_l = sentinel.data.new_parsed
        if l.linetype == LineType.SECTION or new_l.linetype == LineType.SECTION then
          if sentinel.data.deleted then
            linkedlist.remove(sections_ll[sentinel.data.deleted], sentinel.data.section)
          end
          if sentinel.data.new_section then
            sentinel.data.section = sentinel.data.new_section
          end
          sentinel.data.deleted = nil
          sentinel.data.inserted = nil

        end
      end

      for n, _ in pairs(reparsed) do
        if n.data.new_parsed then
          n.data.parsed = n.data.new_parsed
          n.data.new_parsed = nil
        end
      end

      for n, _ in pairs(reparsed) do
        local sentinel = n
        if sentinel.data.parsed.linetype ~= LineType.EMPTY then
          local virtual
          do 
            local l = sentinel.data.parsed
            if l.linetype == LineType.TEXT then
              virtual = false
            else
              virtual = true
            end
          end

          local cur = n.next
          while cur do
            if cur.data.type == UNTANGLED.CHAR then
              cur.data.virtual = virtual
            elseif cur.data.type == UNTANGLED.SENTINEL then
              if cur.data.new_parsed and cur.data.new_parsed.linetype == LineType.EMPTY then
              else
                break
              end
            end
            cur = cur.next
          end
        end
      end

      for cur, _ in pairs(reparsed) do
        local l = cur.data.parsed
        if l.linetype == LineType.EMPTY then
          linkedlist.remove(content, cur)
        end
      end


      if callback then
        callback(changes)
      end

      if show_playground then
        vim.api.nvim_buf_clear_namespace(0, ns_debug, 0, -1)

        vim.schedule(function()
          local lnum = 0
          local cur = content.head
          while cur do
            local sentinel = cur
            cur = cur.next
            local line = ""
            local changed = false
            local empty = true
            while cur do
              if cur.data.deleted or cur.data.inserted then
                changed = true
              end

              if cur.data:is_newline() and not cur.data.deleted then
                cur = cur.next
                empty = false
                break
              end

              if cur.data.type == UNTANGLED.CHAR and not cur.data.deleted then
                empty = false
                line = line .. cur.data.sym
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

        end)

        for _, change in ipairs(changes) do
          local off, del, ins, ins_text = unpack(change)
          ins_text = ins_text or ""
          local s1 = playground_text:sub(1, off)
          local s2 = playground_text:sub(off+del+1)
          playground_text = s1 .. ins_text .. s2

        end

        vim.schedule(function()
          local lines = vim.split(playground_text, "\n")
          vim.api.nvim_buf_set_lines(playground_buf, 0, -1, true, lines)
          local lines = {}
          local single_line = {}
          for data in linkedlist.iter(content) do
            if data.type == UNTANGLED.CHAR then
              table.insert(single_line, "CHAR " .. vim.inspect(data.sym) .. " " .. M.get_virtual(data.virtual))
            elseif data.type == UNTANGLED.SENTINEL then
              if #single_line > 0 then
                table.insert(lines, table.concat(single_line, " "))
                single_line = {}
              end

              table.insert(lines, "SENTINEL " .. M.get_linetype(data.parsed.linetype))
            end
          end

          if single_line ~= "" then
            table.insert(lines, table.concat(single_line, " "))
          end

          vim.api.nvim_buf_set_lines(internal_buf, 0, -1, true, lines)

        end)
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

function M.get_linetype(t)
  if t == LineType.EMPTY then return "EMPTY"
  elseif t == LineType.SECTION then return "SECTION"
  elseif t == LineType.REFERENCE then return "REFERENCE"
  elseif t == LineType.TEXT then return "TEXT"
  else return "UNKNOWN" end
end

function M.get_virtual(v)
  if v then return "v"
  else return " " end
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
