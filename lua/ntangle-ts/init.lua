-- Generated from attach.lua.t, build_lookup.lua.t, debug.lua.t, hl_cache.lua.t, incremental.lua.t, init.lua.t, linkedlist.lua.t, on_buf.lua.t, on_line.lua.t, on_win.lua.t, override_decoration_provider.lua.t, parse.lua.t, parser.lua.t using ntangle.nvim
local backlookup = {}
local backlookup = {}

local getLinetype

local tangleRec

local tangled_ll = {}

local LineType = {
	TANGLED = 4,
	SENTINEL = 5,
	
	REFERENCE = 1,
	TEXT = 2,
	SECTION = 3,
	
}

local linkedlist = {}

local backbuf = {}

local highlighter = vim.treesitter.highlighter

local ns

local trees = {}
local sources = {}

local lang = {}

local M = {}
function M.attach()
  local buf = vim.api.nvim_get_current_buf()
  
  if backbuf[buf] then
    return
  end
  

  local lookup = {}
  local bufs = {}

  local root_set = {}
  
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, true)
  
  
  local untangled_ll = {}
  local sections_ll = {}
  
  local linecount = vim.api.nvim_buf_line_count(buf)
  for i=0,linecount-1 do
    local line = vim.api.nvim_buf_get_lines(buf, i, i+1, true)[1]
  
    if string.match(line, "^@[^@]%S*[+-]?=%s*$") then
      local _, _, name, op = string.find(line, "^@(%S-)([+-]?=)%s*$")
      
      local l = { linetype = LineType.SECTION, str = name, op = op }
      
      insert_after = linkedlist.insert_after(untangled_ll, insert_after, l)
      
      local it = insert_after and insert_after.prev
      while it do
        if it.data.linetype == LineType.SECTION and it.data.str == name then
          break
        end
        it = it.prev
      end
      
      local section
      if it then
        section = linkedlist.insert_after(sections_ll[name], it.data.section, insert_after)
        insert_after.data.section = section
      else
        sections_ll[name] = sections_ll[name] or {}
        section = linkedlist.push_front(sections_ll[name], insert_after)
      end
      l.section = section
      
      local ref_it
      if op == "+=" then
        section = section.next
        while section do
          local it = section.data
          if it.data.op == "+=" then
            ref_it = it.data.tangled
          end
          section = section.next
        end
      elseif op == "-=" then
        section = section.prev
        while section do
          local it = section.data
          if it.data.op == "-=" then
            ref_it = it.data.tangled
            break
          end
          section = section.prev
        end
      end
      
      if not ref_it then
        if op == "+=" then
          ref_it = {}
          for line in linkedlist.iter(untangled_ll) do
            if line.linetype == LineType.REFERENCE and line.str == name then
              for _, ref in ipairs(line.tangled) do
                table.insert(ref_it, ref[2])
              end
            end
          end
        elseif op == "-=" then
          ref_it = {}
          for line in linkedlist.iter(untangled_ll) do
            if line.linetype == LineType.REFERENCE and line.str == name then
              for _, ref in ipairs(line.tangled) do
                table.insert(ref_it, ref[1])
              end
            end
          end
        end
      end
      
      l.tangled = {}
      if op == "+=" then
        for _, ref in ipairs(ref_it) do
          local section = linkedlist.insert_before(tangled_ll, ref, {
            linetype = LineType.SENTINEL,
            prefix = ref.prev.data.prefix,
            untangled = insert_after
          })
          table.insert(l.tangled, section)
        end
      elseif op == "-=" then
        for _, ref in ipairs(ref_it) do
          local section = linkedlist.insert_after(tangled_ll, ref, {
            linetype = LineType.SENTINEL,
            prefix = ref.data.prefix,
            untangled = insert_after
          })
          table.insert(l.tangled, section)
        end
      end
      
    
      if op == "=" then
        local start_file = linkedlist.push_back(tangled_ll, {
          linetype = LineType.SENTINEL,
          prefix = "",
          line = "START " .. name,
          untangled = insert_after,
        })
      
        local end_file = linkedlist.push_back(tangled_ll, {
          linetype = LineType.SENTINEL,
          prefix = "",
          line = "END " .. name,
          untangled = insert_after,
        })
      
        l.tangled = { start_file }
        l.extra_tangled = end_file
        root_set[l.str] = insert_after
      end
      
    
      local it = insert_after and insert_after.next
      while it do
        local cur_delete = it
        if it.data.linetype == LineType.SECTION then
          break
        elseif cur_delete.data.linetype == LineType.REFERENCE then
          for _, ref in ipairs(cur_delete.data.tangled) do
            local ref_start, ref_end = unpack(ref)
            local copy = ref_start
            local quit = false
            while copy and not quit do
              if copy == ref_end then quit = true end
              local to_delete = copy
              local untangled = to_delete.data.untangled
              if not untangled then
                print("Something went south.")
              elseif untangled.data.linetype == LineType.TEXT then
                untangled.data.tangled = vim.tbl_filter(function(x) return x ~= to_delete end, untangled.data.tangled)
              elseif untangled.data.linetype == LineType.REFERENCE then
                untangled.data.tangled = vim.tbl_filter(function(x) return x[1] ~= to_delete and x[2] ~= to_delete end, untangled.data.tangled)
              elseif untangled.data.linetype == LineType.SECTION then
                untangled.data.tangled = vim.tbl_filter(function(x) return x ~= to_delete end, untangled.data.tangled)
              end
              
              linkedlist.remove(tangled_ll, to_delete)
              copy = copy.next
            end
          end
        
        else
          if cur_delete.data.tangled then
            for _, ref in ipairs(cur_delete.data.tangled) do
              linkedlist.remove(tangled_ll, ref)
            end
          end
          
        end
        
        it = it.next
      end
      
      local it = insert_after and insert_after.next
      while it do
        local insert_after = it.prev
        if it.data.linetype == LineType.SECTION then
          break
        elseif it.data.linetype == LineType.REFERENCE then
          local l = it.data
          local tangled = {}
          if insert_after then
            if insert_after.data.linetype == LineType.TEXT then
              for _, ref in ipairs(insert_after.data.tangled) do
                table.insert(tangled, ref)
              end
            elseif insert_after.data.linetype == LineType.REFERENCE then
              for _, ref in ipairs(insert_after.data.tangled) do
                local start_ref, end_ref = unpack(ref)
                table.insert(tangled, end_ref)
              end
            elseif insert_after.data.linetype == LineType.SECTION then
              for _, ref in ipairs(insert_after.data.tangled) do
                table.insert(tangled, ref)
              end
            end
          end
          
          local name = it.data.str
          l.tangled = {}
          for _, ref in ipairs(tangled) do
            local ref_start, ref_end = tangleRec(name, sections_ll, tangled_ll, ref, ref.data.prefix .. l.prefix, {})
            table.insert(l.tangled, {ref_start, ref_end})
            ref_start.data.untangled = it
            ref_end.data.untangled = it
            ref_end.data.prefix = ref.data.prefix
          end
          
        
        else
          local l = it.data
          local line = l.str
          local tangled = {}
          if insert_after then
            if insert_after.data.linetype == LineType.TEXT then
              for _, ref in ipairs(insert_after.data.tangled) do
                table.insert(tangled, ref)
              end
            elseif insert_after.data.linetype == LineType.REFERENCE then
              for _, ref in ipairs(insert_after.data.tangled) do
                local start_ref, end_ref = unpack(ref)
                table.insert(tangled, end_ref)
              end
            elseif insert_after.data.linetype == LineType.SECTION then
              for _, ref in ipairs(insert_after.data.tangled) do
                table.insert(tangled, ref)
              end
            end
          end
          
          l.tangled = {}
          if tangled then
            for _, ref in ipairs(tangled) do
              local new_node = linkedlist.insert_after(tangled_ll, ref, {
                linetype = LineType.TANGLED,
                prefix = ref.data.prefix,
                line = ref.data.prefix .. line,
                untangled = it,
              })
              table.insert(l.tangled, new_node)
            end
          end
          
        end
        
        it = it.next
      end
      
    
    elseif string.match(line, "^%s*@[^@]%S*%s*$") then
      local _, _, prefix, name = string.find(line, "^(%s*)@(%S+)%s*$")
      if name == nil then
      	print(line)
      end
      
    	local l = { 
    		linetype = LineType.REFERENCE, 
    		str = name,
    		prefix = prefix
    	}
    	
      local tangled = {}
      if insert_after then
        if insert_after.data.linetype == LineType.TEXT then
          for _, ref in ipairs(insert_after.data.tangled) do
            table.insert(tangled, ref)
          end
        elseif insert_after.data.linetype == LineType.REFERENCE then
          for _, ref in ipairs(insert_after.data.tangled) do
            local start_ref, end_ref = unpack(ref)
            table.insert(tangled, end_ref)
          end
        elseif insert_after.data.linetype == LineType.SECTION then
          for _, ref in ipairs(insert_after.data.tangled) do
            table.insert(tangled, ref)
          end
        end
      end
      
      insert_after = linkedlist.insert_after(untangled_ll, insert_after, l)
      
      local it = insert_after
      l.tangled = {}
      for _, ref in ipairs(tangled) do
        local ref_start, ref_end = tangleRec(name, sections_ll, tangled_ll, ref, ref.data.prefix .. l.prefix, {})
        table.insert(l.tangled, {ref_start, ref_end})
        ref_start.data.untangled = it
        ref_end.data.untangled = it
        ref_end.data.prefix = ref.data.prefix
      end
      
    
    else
      local l = { 
      	linetype = LineType.TEXT, 
      	str = line 
      }
      local tangled = {}
      if insert_after then
        if insert_after.data.linetype == LineType.TEXT then
          for _, ref in ipairs(insert_after.data.tangled) do
            table.insert(tangled, ref)
          end
        elseif insert_after.data.linetype == LineType.REFERENCE then
          for _, ref in ipairs(insert_after.data.tangled) do
            local start_ref, end_ref = unpack(ref)
            table.insert(tangled, end_ref)
          end
        elseif insert_after.data.linetype == LineType.SECTION then
          for _, ref in ipairs(insert_after.data.tangled) do
            table.insert(tangled, ref)
          end
        end
      end
      
      insert_after = linkedlist.insert_after(untangled_ll, insert_after, l)
      
      local it = insert_after
      l.tangled = {}
      if tangled then
        for _, ref in ipairs(tangled) do
          local new_node = linkedlist.insert_after(tangled_ll, ref, {
            linetype = LineType.TANGLED,
            prefix = ref.data.prefix,
            line = ref.data.prefix .. line,
            untangled = it,
          })
          table.insert(l.tangled, new_node)
        end
      end
      
    end
    
  end
  
  -- @fill_output_buf
  
  local lnum = 1
  for line in linkedlist.iter(untangled_ll) do
    line.lnum = lnum
    lnum = lnum + 1
  end
  
  local lookup = {}
  
  local tangle_lnum = 1
  for line in linkedlist.iter(tangled_ll) do
    if line.linetype == LineType.TANGLED then
      lookup[line.untangled.data.lnum] = { tangle_lnum, string.len(line.prefix) }
      tangle_lnum = tangle_lnum + 1
    end
  end
  
  backlookup[buf] = lookup
  
  local source_lines = {}
  
  for line in linkedlist.iter(tangled_ll) do
    if line.linetype == LineType.TANGLED then
      table.insert(source_lines, line.line)
    end
  end
  
  sources[buf] = table.concat(source_lines, "\n")

  backbuf[buf] = true
  
  local ft = vim.api.nvim_buf_get_option(buf, "ft")
  local parser = vim._create_ts_parser(ft)
  lang[buf] = ft
  
  
  local local_parser = vim.treesitter.get_parser()
  local_parser._callbacks.changedtree = {}
  local_parser._callbacks.bytes = {}
  trees[buf] = parser:parse(nil, sources[buf])
  

  vim.api.nvim_buf_attach(buf, true, {
    on_lines = function(_, _, _, firstline, lastline, new_lastline, _)
      local delete_this = untangled_ll.head
      for _=1,firstline do
        delete_this = delete_this.next
      end
      
      for _=firstline,lastline-1 do
        local cur_delete = delete_this
        if not cur_delete then break end
        delete_this = delete_this.next
      
        if cur_delete.data.linetype == LineType.SECTION then
          local insert_after = cur_delete
          if cur_delete.data.op == "=" then
            linkedlist.remove(tangled_ll, cur_delete.data.tangled[1])
            linkedlist.remove(tangled_ll, cur_delete.data.extra_tangled)
            
            root_set[cur_delete.data.str] = nil
            
          else
            for _, ref in ipairs(cur_delete.data.tangled) do
              linkedlist.remove(tangled_ll, ref)
            end
          end
          
          local it = insert_after and insert_after.next
          while it do
            local cur_delete = it
            if it.data.linetype == LineType.SECTION then
              break
            elseif cur_delete.data.linetype == LineType.REFERENCE then
              for _, ref in ipairs(cur_delete.data.tangled) do
                local ref_start, ref_end = unpack(ref)
                local copy = ref_start
                local quit = false
                while copy and not quit do
                  if copy == ref_end then quit = true end
                  local to_delete = copy
                  local untangled = to_delete.data.untangled
                  if not untangled then
                    print("Something went south.")
                  elseif untangled.data.linetype == LineType.TEXT then
                    untangled.data.tangled = vim.tbl_filter(function(x) return x ~= to_delete end, untangled.data.tangled)
                  elseif untangled.data.linetype == LineType.REFERENCE then
                    untangled.data.tangled = vim.tbl_filter(function(x) return x[1] ~= to_delete and x[2] ~= to_delete end, untangled.data.tangled)
                  elseif untangled.data.linetype == LineType.SECTION then
                    untangled.data.tangled = vim.tbl_filter(function(x) return x ~= to_delete end, untangled.data.tangled)
                  end
                  
                  linkedlist.remove(tangled_ll, to_delete)
                  copy = copy.next
                end
              end
            
            else
              if cur_delete.data.tangled then
                for _, ref in ipairs(cur_delete.data.tangled) do
                  linkedlist.remove(tangled_ll, ref)
                end
              end
              
            end
            
            it = it.next
          end
          
          if cur_delete then
            linkedlist.remove(untangled_ll, cur_delete)
          end
          
          local it = insert_after and insert_after.next
          while it do
            local insert_after = it.prev
            if it.data.linetype == LineType.SECTION then
              break
            elseif it.data.linetype == LineType.REFERENCE then
              local l = it.data
              local tangled = {}
              if insert_after then
                if insert_after.data.linetype == LineType.TEXT then
                  for _, ref in ipairs(insert_after.data.tangled) do
                    table.insert(tangled, ref)
                  end
                elseif insert_after.data.linetype == LineType.REFERENCE then
                  for _, ref in ipairs(insert_after.data.tangled) do
                    local start_ref, end_ref = unpack(ref)
                    table.insert(tangled, end_ref)
                  end
                elseif insert_after.data.linetype == LineType.SECTION then
                  for _, ref in ipairs(insert_after.data.tangled) do
                    table.insert(tangled, ref)
                  end
                end
              end
              
              local name = it.data.str
              l.tangled = {}
              for _, ref in ipairs(tangled) do
                local ref_start, ref_end = tangleRec(name, sections_ll, tangled_ll, ref, ref.data.prefix .. l.prefix, {})
                table.insert(l.tangled, {ref_start, ref_end})
                ref_start.data.untangled = it
                ref_end.data.untangled = it
                ref_end.data.prefix = ref.data.prefix
              end
              
            
            else
              local l = it.data
              local line = l.str
              local tangled = {}
              if insert_after then
                if insert_after.data.linetype == LineType.TEXT then
                  for _, ref in ipairs(insert_after.data.tangled) do
                    table.insert(tangled, ref)
                  end
                elseif insert_after.data.linetype == LineType.REFERENCE then
                  for _, ref in ipairs(insert_after.data.tangled) do
                    local start_ref, end_ref = unpack(ref)
                    table.insert(tangled, end_ref)
                  end
                elseif insert_after.data.linetype == LineType.SECTION then
                  for _, ref in ipairs(insert_after.data.tangled) do
                    table.insert(tangled, ref)
                  end
                end
              end
              
              l.tangled = {}
              if tangled then
                for _, ref in ipairs(tangled) do
                  local new_node = linkedlist.insert_after(tangled_ll, ref, {
                    linetype = LineType.TANGLED,
                    prefix = ref.data.prefix,
                    line = ref.data.prefix .. line,
                    untangled = it,
                  })
                  table.insert(l.tangled, new_node)
                end
              end
              
            end
            
            it = it.next
          end
          
          cur_delete = nil
        
        elseif cur_delete.data.linetype == LineType.REFERENCE then
          for _, ref in ipairs(cur_delete.data.tangled) do
            local ref_start, ref_end = unpack(ref)
            local copy = ref_start
            local quit = false
            while copy and not quit do
              if copy == ref_end then quit = true end
              local to_delete = copy
              local untangled = to_delete.data.untangled
              if not untangled then
                print("Something went south.")
              elseif untangled.data.linetype == LineType.TEXT then
                untangled.data.tangled = vim.tbl_filter(function(x) return x ~= to_delete end, untangled.data.tangled)
              elseif untangled.data.linetype == LineType.REFERENCE then
                untangled.data.tangled = vim.tbl_filter(function(x) return x[1] ~= to_delete and x[2] ~= to_delete end, untangled.data.tangled)
              elseif untangled.data.linetype == LineType.SECTION then
                untangled.data.tangled = vim.tbl_filter(function(x) return x ~= to_delete end, untangled.data.tangled)
              end
              
              linkedlist.remove(tangled_ll, to_delete)
              copy = copy.next
            end
          end
        
        else
          if cur_delete.data.tangled then
            for _, ref in ipairs(cur_delete.data.tangled) do
              linkedlist.remove(tangled_ll, ref)
            end
          end
          
        end
        
      
        if cur_delete then
          linkedlist.remove(untangled_ll, cur_delete)
        end
        
      end
      
      local insert_after = untangled_ll.head
      for _=1,firstline-1 do
        insert_after = insert_after.next
      end
      
      if firstline == 0 then
        insert_after = nil
      end
      
      for i=firstline,new_lastline-1 do
        local line = vim.api.nvim_buf_get_lines(buf, i, i+1, true)[1]
      
        if string.match(line, "^@[^@]%S*[+-]?=%s*$") then
          local _, _, name, op = string.find(line, "^@(%S-)([+-]?=)%s*$")
          
          local l = { linetype = LineType.SECTION, str = name, op = op }
          
          insert_after = linkedlist.insert_after(untangled_ll, insert_after, l)
          
          local it = insert_after and insert_after.prev
          while it do
            if it.data.linetype == LineType.SECTION and it.data.str == name then
              break
            end
            it = it.prev
          end
          
          local section
          if it then
            section = linkedlist.insert_after(sections_ll[name], it.data.section, insert_after)
            insert_after.data.section = section
          else
            sections_ll[name] = sections_ll[name] or {}
            section = linkedlist.push_front(sections_ll[name], insert_after)
          end
          l.section = section
          
          local ref_it
          if op == "+=" then
            section = section.next
            while section do
              local it = section.data
              if it.data.op == "+=" then
                ref_it = it.data.tangled
              end
              section = section.next
            end
          elseif op == "-=" then
            section = section.prev
            while section do
              local it = section.data
              if it.data.op == "-=" then
                ref_it = it.data.tangled
                break
              end
              section = section.prev
            end
          end
          
          if not ref_it then
            if op == "+=" then
              ref_it = {}
              for line in linkedlist.iter(untangled_ll) do
                if line.linetype == LineType.REFERENCE and line.str == name then
                  for _, ref in ipairs(line.tangled) do
                    table.insert(ref_it, ref[2])
                  end
                end
              end
            elseif op == "-=" then
              ref_it = {}
              for line in linkedlist.iter(untangled_ll) do
                if line.linetype == LineType.REFERENCE and line.str == name then
                  for _, ref in ipairs(line.tangled) do
                    table.insert(ref_it, ref[1])
                  end
                end
              end
            end
          end
          
          l.tangled = {}
          if op == "+=" then
            for _, ref in ipairs(ref_it) do
              local section = linkedlist.insert_before(tangled_ll, ref, {
                linetype = LineType.SENTINEL,
                prefix = ref.prev.data.prefix,
                untangled = insert_after
              })
              table.insert(l.tangled, section)
            end
          elseif op == "-=" then
            for _, ref in ipairs(ref_it) do
              local section = linkedlist.insert_after(tangled_ll, ref, {
                linetype = LineType.SENTINEL,
                prefix = ref.data.prefix,
                untangled = insert_after
              })
              table.insert(l.tangled, section)
            end
          end
          
        
          if op == "=" then
            local start_file = linkedlist.push_back(tangled_ll, {
              linetype = LineType.SENTINEL,
              prefix = "",
              line = "START " .. name,
              untangled = insert_after,
            })
          
            local end_file = linkedlist.push_back(tangled_ll, {
              linetype = LineType.SENTINEL,
              prefix = "",
              line = "END " .. name,
              untangled = insert_after,
            })
          
            l.tangled = { start_file }
            l.extra_tangled = end_file
            root_set[l.str] = insert_after
          end
          
        
          local it = insert_after and insert_after.next
          while it do
            local cur_delete = it
            if it.data.linetype == LineType.SECTION then
              break
            elseif cur_delete.data.linetype == LineType.REFERENCE then
              for _, ref in ipairs(cur_delete.data.tangled) do
                local ref_start, ref_end = unpack(ref)
                local copy = ref_start
                local quit = false
                while copy and not quit do
                  if copy == ref_end then quit = true end
                  local to_delete = copy
                  local untangled = to_delete.data.untangled
                  if not untangled then
                    print("Something went south.")
                  elseif untangled.data.linetype == LineType.TEXT then
                    untangled.data.tangled = vim.tbl_filter(function(x) return x ~= to_delete end, untangled.data.tangled)
                  elseif untangled.data.linetype == LineType.REFERENCE then
                    untangled.data.tangled = vim.tbl_filter(function(x) return x[1] ~= to_delete and x[2] ~= to_delete end, untangled.data.tangled)
                  elseif untangled.data.linetype == LineType.SECTION then
                    untangled.data.tangled = vim.tbl_filter(function(x) return x ~= to_delete end, untangled.data.tangled)
                  end
                  
                  linkedlist.remove(tangled_ll, to_delete)
                  copy = copy.next
                end
              end
            
            else
              if cur_delete.data.tangled then
                for _, ref in ipairs(cur_delete.data.tangled) do
                  linkedlist.remove(tangled_ll, ref)
                end
              end
              
            end
            
            it = it.next
          end
          
          local it = insert_after and insert_after.next
          while it do
            local insert_after = it.prev
            if it.data.linetype == LineType.SECTION then
              break
            elseif it.data.linetype == LineType.REFERENCE then
              local l = it.data
              local tangled = {}
              if insert_after then
                if insert_after.data.linetype == LineType.TEXT then
                  for _, ref in ipairs(insert_after.data.tangled) do
                    table.insert(tangled, ref)
                  end
                elseif insert_after.data.linetype == LineType.REFERENCE then
                  for _, ref in ipairs(insert_after.data.tangled) do
                    local start_ref, end_ref = unpack(ref)
                    table.insert(tangled, end_ref)
                  end
                elseif insert_after.data.linetype == LineType.SECTION then
                  for _, ref in ipairs(insert_after.data.tangled) do
                    table.insert(tangled, ref)
                  end
                end
              end
              
              local name = it.data.str
              l.tangled = {}
              for _, ref in ipairs(tangled) do
                local ref_start, ref_end = tangleRec(name, sections_ll, tangled_ll, ref, ref.data.prefix .. l.prefix, {})
                table.insert(l.tangled, {ref_start, ref_end})
                ref_start.data.untangled = it
                ref_end.data.untangled = it
                ref_end.data.prefix = ref.data.prefix
              end
              
            
            else
              local l = it.data
              local line = l.str
              local tangled = {}
              if insert_after then
                if insert_after.data.linetype == LineType.TEXT then
                  for _, ref in ipairs(insert_after.data.tangled) do
                    table.insert(tangled, ref)
                  end
                elseif insert_after.data.linetype == LineType.REFERENCE then
                  for _, ref in ipairs(insert_after.data.tangled) do
                    local start_ref, end_ref = unpack(ref)
                    table.insert(tangled, end_ref)
                  end
                elseif insert_after.data.linetype == LineType.SECTION then
                  for _, ref in ipairs(insert_after.data.tangled) do
                    table.insert(tangled, ref)
                  end
                end
              end
              
              l.tangled = {}
              if tangled then
                for _, ref in ipairs(tangled) do
                  local new_node = linkedlist.insert_after(tangled_ll, ref, {
                    linetype = LineType.TANGLED,
                    prefix = ref.data.prefix,
                    line = ref.data.prefix .. line,
                    untangled = it,
                  })
                  table.insert(l.tangled, new_node)
                end
              end
              
            end
            
            it = it.next
          end
          
        
        elseif string.match(line, "^%s*@[^@]%S*%s*$") then
          local _, _, prefix, name = string.find(line, "^(%s*)@(%S+)%s*$")
          if name == nil then
          	print(line)
          end
          
        	local l = { 
        		linetype = LineType.REFERENCE, 
        		str = name,
        		prefix = prefix
        	}
        	
          local tangled = {}
          if insert_after then
            if insert_after.data.linetype == LineType.TEXT then
              for _, ref in ipairs(insert_after.data.tangled) do
                table.insert(tangled, ref)
              end
            elseif insert_after.data.linetype == LineType.REFERENCE then
              for _, ref in ipairs(insert_after.data.tangled) do
                local start_ref, end_ref = unpack(ref)
                table.insert(tangled, end_ref)
              end
            elseif insert_after.data.linetype == LineType.SECTION then
              for _, ref in ipairs(insert_after.data.tangled) do
                table.insert(tangled, ref)
              end
            end
          end
          
          insert_after = linkedlist.insert_after(untangled_ll, insert_after, l)
          
          local it = insert_after
          l.tangled = {}
          for _, ref in ipairs(tangled) do
            local ref_start, ref_end = tangleRec(name, sections_ll, tangled_ll, ref, ref.data.prefix .. l.prefix, {})
            table.insert(l.tangled, {ref_start, ref_end})
            ref_start.data.untangled = it
            ref_end.data.untangled = it
            ref_end.data.prefix = ref.data.prefix
          end
          
        
        else
          local l = { 
          	linetype = LineType.TEXT, 
          	str = line 
          }
          local tangled = {}
          if insert_after then
            if insert_after.data.linetype == LineType.TEXT then
              for _, ref in ipairs(insert_after.data.tangled) do
                table.insert(tangled, ref)
              end
            elseif insert_after.data.linetype == LineType.REFERENCE then
              for _, ref in ipairs(insert_after.data.tangled) do
                local start_ref, end_ref = unpack(ref)
                table.insert(tangled, end_ref)
              end
            elseif insert_after.data.linetype == LineType.SECTION then
              for _, ref in ipairs(insert_after.data.tangled) do
                table.insert(tangled, ref)
              end
            end
          end
          
          insert_after = linkedlist.insert_after(untangled_ll, insert_after, l)
          
          local it = insert_after
          l.tangled = {}
          if tangled then
            for _, ref in ipairs(tangled) do
              local new_node = linkedlist.insert_after(tangled_ll, ref, {
                linetype = LineType.TANGLED,
                prefix = ref.data.prefix,
                line = ref.data.prefix .. line,
                untangled = it,
              })
              table.insert(l.tangled, new_node)
            end
          end
          
        end
        
      end
      
      
      -- @fill_output_buf
      
      local lnum = 1
      for line in linkedlist.iter(untangled_ll) do
        line.lnum = lnum
        lnum = lnum + 1
      end
      
      local lookup = {}
      
      local tangle_lnum = 1
      for line in linkedlist.iter(tangled_ll) do
        if line.linetype == LineType.TANGLED then
          lookup[line.untangled.data.lnum] = { tangle_lnum, string.len(line.prefix) }
          tangle_lnum = tangle_lnum + 1
        end
      end
      
      backlookup[buf] = lookup
      
      local source_lines = {}
      
      for line in linkedlist.iter(tangled_ll) do
        if line.linetype == LineType.TANGLED then
          table.insert(source_lines, line.line)
        end
      end
      
      sources[buf] = table.concat(source_lines, "\n")

      trees[buf] = parser:parse(nil, sources[buf])
      
    end
  })
end

function M.print_lookup()
  print("backlookup " .. vim.inspect(backlookup))
end
function getLinetype(linetype)
  if linetype == LineType.TEXT then return "TEXT"
  elseif linetype == LineType.REFERENCE then return "REFERENCE"
  elseif linetype == LineType.SECTION then return "SECTION"
  elseif linetype == LineType.TANGLED then return "TANGLED"
  elseif linetype == LineType.SENTINEL then return "SENTINEL"
  
  end
end

function tangleRec(name, sections_ll, tangled_ll, tangled_it, prefix, stack)
  local start_node = linkedlist.insert_after(tangled_ll, tangled_it, { 
    linetype = LineType.SENTINEL, 
    prefix = prefix, 
    line = "start " .. name 
  })

  tangled_it = start_node 

  local end_node = linkedlist.insert_after(tangled_ll, tangled_it, { 
    linetype = LineType.SENTINEL, 
    prefix = prefix, 
    line = "end " .. name 
  })

  if not sections_ll[name] then
    return start_node, end_node
  end
  
  if vim.tbl_contains(stack, name) then
    return start_node, end_node
  end
  
  table.insert(stack, name)
  

  for node in linkedlist.iter(sections_ll[name]) do
    local l = node.data
    if l.op == "+=" then
      local after_this = end_node.prev
      local section_sentinel = linkedlist.insert_after(tangled_ll, after_this, { 
        linetype = LineType.SENTINEL, 
        prefix = after_this.node.prefix,
        untangled = node
      })
      l.tangled = l.tangled or {}
      table.insert(l.tangled, section_sentinel)
      
      node = node.next
      while node do
        if node.data.linetype == LineType.TEXT then
          local l = { 
            linetype = LineType.TANGLED, 
            prefix = prefix,
            line = prefix .. node.data.str,
          }
          
          after_this = linkedlist.insert_after(tangled_ll, after_this, l)
          
          l.untangled = node
      
          node.data.tangled = node.data.tangled or {}
          table.insert(node.data.tangled, after_this)
        elseif node.data.linetype == LineType.REFERENCE then
          local ref_start, ref_end = tangleRec(node.data.str, sections_ll, tangled_ll, after_this, prefix .. node.data.prefix, stack)
          node.data.tangled = node.data.tangled or {}
          table.insert(node.data.tangled, {ref_start, ref_end})
      
          ref_start.data.untangled = node
          ref_end.data.untangled = node
          ref_end.data.prefix = node.data.prefix
      
          after_this = ref_end
        elseif node.data.linetype == LineType.SECTION then
          break
        end
        node = node.next
      end
      
    
    elseif l.op == "-=" then
      local after_this = start_node
      local section_sentinel = linkedlist.insert_after(tangled_ll, after_this, { 
        linetype = LineType.SENTINEL, 
        prefix = after_this.node.prefix,
        untangled = node
      })
      l.tangled = l.tangled or {}
      table.insert(l.tangled, section_sentinel)
      
      node = node.next
      while node do
        if node.data.linetype == LineType.TEXT then
          local l = { 
            linetype = LineType.TANGLED, 
            prefix = prefix,
            line = prefix .. node.data.str,
          }
          
          after_this = linkedlist.insert_after(tangled_ll, after_this, l)
          
          l.untangled = node
      
          node.data.tangled = node.data.tangled or {}
          table.insert(node.data.tangled, after_this)
        elseif node.data.linetype == LineType.REFERENCE then
          local ref_start, ref_end = tangleRec(node.data.str, sections_ll, tangled_ll, after_this, prefix .. node.data.prefix, stack)
          node.data.tangled = node.data.tangled or {}
          table.insert(node.data.tangled, {ref_start, ref_end})
      
          ref_start.data.untangled = node
          ref_end.data.untangled = node
          ref_end.data.prefix = node.data.prefix
      
          after_this = ref_end
        elseif node.data.linetype == LineType.SECTION then
          break
        end
        node = node.next
      end
      
    
    else
      local after_this = start_node
      local section_sentinel = linkedlist.insert_after(tangled_ll, after_this, { 
        linetype = LineType.SENTINEL, 
        prefix = after_this.node.prefix,
        untangled = node
      })
      l.tangled = l.tangled or {}
      table.insert(l.tangled, section_sentinel)
      
      node = node.next
      while node do
        if node.data.linetype == LineType.TEXT then
          local l = { 
            linetype = LineType.TANGLED, 
            prefix = prefix,
            line = prefix .. node.data.str,
          }
          
          after_this = linkedlist.insert_after(tangled_ll, after_this, l)
          
          l.untangled = node
      
          node.data.tangled = node.data.tangled or {}
          table.insert(node.data.tangled, after_this)
        elseif node.data.linetype == LineType.REFERENCE then
          local ref_start, ref_end = tangleRec(node.data.str, sections_ll, tangled_ll, after_this, prefix .. node.data.prefix, stack)
          node.data.tangled = node.data.tangled or {}
          table.insert(node.data.tangled, {ref_start, ref_end})
      
          ref_start.data.untangled = node
          ref_end.data.untangled = node
          ref_end.data.prefix = node.data.prefix
      
          after_this = ref_end
        elseif node.data.linetype == LineType.SECTION then
          break
        end
        node = node.next
      end
      
    end
    
  end

  table.remove(stack)
  

  return start_node, end_node
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
function M._on_buf(...)
end
function M._on_line(...)
  local _, _, buf, line = unpack({...})
  if backbuf[buf] then
    local lookup = backlookup[buf]
    
    if lookup[line+1] then
      local tline = line
      local line, indent = unpack(lookup[line+1])
      line = line - 1
      local self = vim.treesitter.highlighter.active[buf]
      local tstree = trees[buf]
      if not tstree then return end
      
      local root_node = tstree:root()
      local root_start_row, _, root_end_row, _ = root_node:range()
      
      -- Only worry about trees within the line range
      if root_start_row > line or root_end_row < line then return end
      
      local highlighter_query = self:get_query(lang[buf])
      
      local state = {
        next_row = 0,
        iter = nil
      }
      
      if state.iter == nil then
        state.iter = highlighter_query:query():iter_captures(root_node, self.bufnr, line, root_end_row + 1)
      end
      
      while line >= state.next_row do
        local capture, node = state.iter()
      
        if capture == nil then break end
      
        local start_row, start_col, end_row, end_col = node:range()
        local hl = highlighter_query.hl_cache[capture]
      
        start_col = start_col - indent
        end_col = end_col - indent
        
      
        if hl and start_row == line and end_row == line then
          vim.api.nvim_buf_set_extmark(buf, ns, tline, start_col,
                                 { end_line = tline, end_col = end_col,
                                   hl_group = hl,
                                   ephemeral = true,
                                   priority = 100 -- Low but leaves room below
                                  })
        end
        if start_row > line then
          state.next_row = start_row
        end
      end
      
      -- @highlight_line_test
    else
      local curline = vim.api.nvim_buf_get_lines(buf, line, line+1, true)[1]
      
      vim.api.nvim_buf_set_extmark(buf, ns, line, 0, { 
          end_col = string.len(curline),
          hl_group = "String",
          ephemeral = true,
          priority = 100 -- Low but leaves room below
      })
      
    end
  
  -- @test_override
  else
    highlighter._on_line(...)
  end
  
end

function M._on_win(...)
  local _, _, buf, _ = unpack({...})
  if backbuf[buf] then
    return true
  else
    highlighter._on_win(...)
  end
end

function M.override()
  local nss = vim.api.nvim_get_namespaces()
  ns = nss["treesitter/highlighter"]
  
  print("override!")
  vim.api.nvim_set_decoration_provider(ns, {
    on_buf = highlighter._on_buf,
    on_line = M._on_line,
    on_win = highlighter._on_win,
  })
end

return M
