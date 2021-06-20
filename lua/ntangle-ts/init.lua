-- Generated using ntangle.nvim
local asm_namespaces = {}

local backlookup = {}
local buf_vars = {}
local buf_backup = {}

local overriden = false

local states = {}

local getLinetype

local tangleRec

local LineType = {
	BUF_DELIM = 7,

	ASSEMBLY = 6,

	TANGLED = 4,
	SENTINEL = 5,

	REFERENCE = 1,
	TEXT = 2,
	SECTION = 3,

}

local backbuf = {}

local highlighter = vim.treesitter.highlighter

local ns

local lang = {}

local cbs_change = {}

local cbs_init = {}

local cbs_deinit = {}

local init_events = {}

local deinit_events = {}

local linkedlist = {}

local function get_line(buf, row)
  local line = vim.api.nvim_buf_get_lines(buf, row, row+1, false)
  if #line == 0 then
    return ""
  else
    return line[1]
  end
end

local M = {}
function M.attach()
  if not overriden then
    M.override()
    overriden = true
  end


  local buf = vim.api.nvim_get_current_buf()


  local bufname = vim.api.nvim_buf_get_name(0)
  local ext = vim.fn.fnamemodify(bufname, ":e:e:r")

  if not vim._ts_has_language(ext) then
    local fname = 'parser/' .. ext .. '.*'
    local paths = vim.api.nvim_get_runtime_file(fname, false)

    if #paths == 0 then
      error("no parser for '"..ext.."' language, see :help treesitter-parsers")
    end

    local path = paths[1]

    -- pcall(function() vim._ts_add_language(path, ext) end)
    vim._ts_add_language(path, ext)
  end

	local parser = vim.treesitter.get_parser(buf, ext)

	vim.treesitter.highlighter.new(parser, {})
	-- @set_filetype_to_original_language
  vim.api.nvim_command("set ei=FileType")
  vim.api.nvim_command("set ft=" .. ext)
  vim.api.nvim_command("runtime! indent/" .. ext .. '.vim')
  vim.api.nvim_command("set ei=")

  vim.fn.matchadd("Conceal", [[\(^\s*@.*\)\@<=_]], 10, -1, { conceal = ' '})
  -- vim.fn.matchadd("Conceal", [[^\s*\zs@\ze.*\([^=]\)]], 10, -1, { conceal = ''})
  -- vim.fn.matchadd("Conceal", [[^\s*\zs@\ze.*=]], 10, -1, { conceal = ''})
  vim.api.nvim_command([[setlocal conceallevel=2]])
  vim.api.nvim_command([[setlocal concealcursor=nc]])
  -- @enable_foldexpr_for_ntangle

  local lookup = {}

  local buf_asm

  local untangled_ll
  local sections_ll
  local tangled_ll
  local root_set
  local parts_ll

  local start_buf, end_buf

  local bufs_set

  local bufname = string.lower(vim.api.nvim_buf_get_name(buf))

  local insert_line
  insert_line = function(i, line, start_buf, end_buf, insert_after)
    if string.match(line, "^@[^@]%S*[+-]?=%s*$") then
      local _, _, name, op = string.find(line, "^@(%S-)([+-]?=)%s*$")

      local l = { linetype = LineType.SECTION, str = name, op = op }

      insert_after = linkedlist.insert_after(untangled_ll, insert_after, l)

      local it = insert_after and insert_after.prev
      while it ~= start_buf do
        if it.data.linetype == LineType.SECTION and it.data.str == name then
          break
        end
        it = it.prev
      end

      local section
      if it ~= start_buf then
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

        local filename
        local buf_asm = (buf_vars[bufname] and buf_vars[bufname].buf_asm) or ""

        local parent_assembly
        parent_assembly = vim.fn.fnamemodify(buf_asm, ":h")

        local root_name = name
        if name == "*" then
          root_name = "tangle/" .. vim.fn.fnamemodify(bufname, ":t:r")
        else
        	if string.find(name, "/") then
        		root_name = name
        	else
        		root_name = "tangle/" .. name
        	end
        end

        local cur_dir = vim.fn.fnamemodify(bufname, ":h")
        filename = cur_dir .. "/" .. parent_assembly .. "/" .. root_name
        filename = string.lower(filename:gsub("\\", "/"))


        root_set[l.str] = {
          filename = filename,
          start_file = start_file,
          end_file = end_file,
          parser = vim._create_ts_parser(ext),
          tree = nil,
        }

        table.insert(init_events, l.str)

      end


      local it = insert_after and insert_after.next
      while it ~= end_buf do
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

              -- linkedlist.remove(tangled_ll, to_delete)
              to_delete.data.remove = true

              copy = copy.next
            end
          end

        else
          if cur_delete.data.tangled then
            for _, ref in ipairs(cur_delete.data.tangled) do
              ref.data.remove = true
            end
          end

        end

        it = it.next
      end

      local it = insert_after and insert_after.next
      while it ~= end_buf do
        local insert_after = it.prev
        if it.data.linetype == LineType.SECTION then
          break
        elseif it.data.linetype == LineType.REFERENCE then
          local l = it.data
          local name = l.str
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
                line = (line ~= "" and ref.data.prefix .. line) or "",
                untangled = it,
                insert = true,
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


    elseif i == 0 and string.match(line, "^##%S+$") then

      local name = string.match(line, "^##(%S*)%s*$")

      local fn = vim.api.nvim_buf_get_name(buf)
      fn = vim.fn.fnamemodify(fn, ":p")
      local parendir = vim.fn.fnamemodify(fn, ":p:h")
      local assembly_parendir = vim.fn.fnamemodify(name, ":h")
      local assembly_tail = vim.fn.fnamemodify(name, ":t")
      local part_tails = {}
      local copy_fn = fn
      local copy_curassembly = name
      while true do
        local part_tail = vim.fn.fnamemodify(copy_fn, ":t")
        table.insert(part_tails, 1, part_tail)
        copy_fn = vim.fn.fnamemodify(copy_fn, ":h")

        copy_curassembly = vim.fn.fnamemodify(copy_curassembly, ":h")
        if copy_curassembly == "." then
          break
        end
        if copy_curassembly ~= ".." and vim.fn.fnamemodify(copy_curassembly, ":h") ~= ".." then
          error("Assembly can't be in a subdirectory (it must be either in parent or same directory")
        end
      end
      local part_tail = table.concat(part_tails, ".")
      local link_name = parendir .. "/" .. assembly_parendir .. "/tangle/" .. assembly_tail .. "." .. part_tail
      local path = vim.fn.fnamemodify(link_name, ":h")

      local l = {
        linetype = LineType.ASSEMBLY,
        str = name,
      }

      insert_after = linkedlist.insert_after(untangled_ll, start_buf, l)

      if buf_asm then
        local delete_this = start_buf.next
        while delete_this ~= end_buf do
          local cur_delete = delete_this
          if not cur_delete then break end
          delete_this = delete_this.next

          if cur_delete.data.linetype == LineType.SECTION then
            local insert_after = cur_delete
            if cur_delete.data.op == "=" then
              linkedlist.remove(tangled_ll, cur_delete.data.tangled[1])
              linkedlist.remove(tangled_ll, cur_delete.data.extra_tangled)

              local root = root_set[cur_delete.data.str]
              if root and root.filename then
                table.insert(deinit_events, root.filename)
              end

              root_set[cur_delete.data.str] = nil

            else
              for _, ref in ipairs(cur_delete.data.tangled) do
                linkedlist.remove(tangled_ll, ref)
              end
            end

            if sections_ll[cur_delete.data.str] then
              local it = sections_ll[cur_delete.data.str].head
              while it do
                if it.data == cur_delete then
                  linkedlist.remove(sections_ll[cur_delete.data.str], it)
                  break
                end
                it = it.next
              end

              if linkedlist.get_size(sections_ll[cur_delete.data.str]) == 0 then
                sections_ll[cur_delete.data.str] = nil
              end
            end


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

                -- linkedlist.remove(tangled_ll, to_delete)
                to_delete.data.remove = true

                copy = copy.next
              end
            end

          else
            if cur_delete.data.tangled then
              for _, ref in ipairs(cur_delete.data.tangled) do
                ref.data.remove = true
              end
            end

          end

        end

        local it = parts_ll.head
        local cur_name = vim.api.nvim_buf_get_name(0)
        while it do
          if it.data.name == buf_name then
            linkedlist.remove(parts_ll, it)
            break
          end
          it = it.next
        end

      end

      local old_untangled_ll = untangled_ll

      local check_links = false
      if not asm_namespaces[name] then
        asm_namespaces[name] = {
          untangled_ll = {},
          tangled_ll = {},
          sections_ll = {},
          root_set = {},
          parts_ll = {},
          bufs_set = {},

        }

        check_links = true
      end

      untangled_ll = asm_namespaces[name].untangled_ll
      sections_ll = asm_namespaces[name].sections_ll
      tangled_ll = asm_namespaces[name].tangled_ll
      root_set = asm_namespaces[name].root_set
      parts_ll = asm_namespaces[name].parts_ll
      bufs_set = asm_namespaces[name].bufs_set

      buf_asm = name

      if type(name) ~= "number" and check_links then
        path = vim.fn.fnamemodify(path, ":p")
        local parts = vim.split(vim.fn.glob(path .. assembly_tail .. ".*.t"), "\n")
        link_name = vim.fn.fnamemodify(link_name, ":p")

        for _, part in ipairs(parts) do
        	if link_name ~= part then
        		local f = io.open(part, "r")
        		local origin_path
        		if f then
        		  origin_path = f:read("*line")
        		  f:close()
        		end

            if origin_path then
              local f = io.open(origin_path, "r")
              if f then
                local start_buf = linkedlist.push_back(untangled_ll, {
                  linetype = LineType.BUF_DELIM,
                  str = "START " .. origin_path,
                })

                local end_buf = linkedlist.push_back(untangled_ll, {
                  linetype = LineType.BUF_DELIM,
                  str = "END " .. origin_path,
                })

                linkedlist.push_back(parts_ll, {
                  start_buf = start_buf,
                  end_buf = end_buf,
                  name = origin_path,
                })

                buf_vars[string.lower(origin_path)] = {
                  buf_asm = buf_asm,
                  start_buf = start_buf,
                  end_buf = end_buf,
                }

              	local lnum = 1
                local insert_after = start_buf
              	while true do
              		local line = f:read("*line")
              		if not line then break end
                  start_buf, end_buf, insert_after = insert_line(nil, line, start_buf, end_buf, insert_after)
              		lnum = lnum + 1
              	end
              	f:close()
              end

            end
        	end
        end

      end

      local part_after = parts_ll.head
      local cur_name = vim.api.nvim_buf_get_name(0)
      while part_after do
        if part_after.data.name > cur_name then
          break
        end
        part_after = part_after.next
      end

      local new_start_buf, new_end_buf
      if not part_after then
        new_start_buf = linkedlist.push_back(untangled_ll, {
          linetype = LineType.BUF_DELIM,
          buf = buf,
          str = "START " .. bufname,
        })

        new_end_buf = linkedlist.push_back(untangled_ll, {
          linetype = LineType.BUF_DELIM,
          buf = buf,
          str = "END " .. bufname,
        })

        linkedlist.push_back(parts_ll, {
          start_buf = new_start_buf,
          end_buf = new_end_buf,
          name = vim.api.nvim_buf_get_name(buf),
        })

      else
        local end_buf_after = part_after.data.start_buf

        new_start_buf = linkedlist.insert_before(untangled_ll, end_buf_after, {
          linetype = LineType.BUF_DELIM,
          buf = buf,
          str = "START " .. buf,
        })


        new_end_buf = linkedlist.insert_after(untangled_ll, new_start_buf, {
          linetype = LineType.BUF_DELIM,
          buf = buf,
          str = "END " .. buf,
        })

        linkedlist.insert_before(parts_ll, part_after, {
          start_buf = start_buf,
          end_buf = end_buf,
          name = cur_name
        })

      end

      local transfer_this = start_buf.next
      local dest = new_start_buf
      while transfer_this ~= end_buf do
        dest = linkedlist.insert_after(untangled_ll, dest, transfer_this.data)
        local delete_this = transfer_this
        transfer_this = transfer_this.next
        linkedlist.remove(old_untangled_ll, delete_this)
      end

      linkedlist.remove(old_untangled_ll, start_buf)
      linkedlist.remove(old_untangled_ll, end_buf)
      old_untangled_ll = nil
      start_buf = new_start_buf
      end_buf = new_end_buf

      bufs_set[buf] = { start_buf, end_buf }


      insert_after = start_buf.next

      do
        local it = start_buf.next.next
        while it ~= end_buf do
          local insert_after = it.prev
          if it.data.linetype == LineType.ASSEMBLY then
          elseif it.data.linetype == LineType.SECTION then
            local l = it.data
            local insert_after = it
            local op = l.op
            local name = l.str
            local it = insert_after and insert_after.prev
            while it ~= start_buf do
              if it.data.linetype == LineType.SECTION and it.data.str == name then
                break
              end
              it = it.prev
            end

            local section
            if it ~= start_buf then
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

              local filename
              local buf_asm = (buf_vars[bufname] and buf_vars[bufname].buf_asm) or ""

              local parent_assembly
              parent_assembly = vim.fn.fnamemodify(buf_asm, ":h")

              local root_name = name
              if name == "*" then
                root_name = "tangle/" .. vim.fn.fnamemodify(bufname, ":t:r")
              else
              	if string.find(name, "/") then
              		root_name = name
              	else
              		root_name = "tangle/" .. name
              	end
              end

              local cur_dir = vim.fn.fnamemodify(bufname, ":h")
              filename = cur_dir .. "/" .. parent_assembly .. "/" .. root_name
              filename = string.lower(filename:gsub("\\", "/"))


              root_set[l.str] = {
                filename = filename,
                start_file = start_file,
                end_file = end_file,
                parser = vim._create_ts_parser(ext),
                tree = nil,
              }

              table.insert(init_events, l.str)

            end


          elseif it.data.linetype == LineType.REFERENCE then
            local l = it.data
            local name = l.str
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
                  line = (line ~= "" and ref.data.prefix .. line) or "",
                  untangled = it,
                  insert = true,
                })
                table.insert(l.tangled, new_node)
              end
            end

          end

          it = it.next
        end
      end


      buf_vars[bufname] = {
        buf_asm = buf_asm,
        start_buf = start_buf,
        end_buf = end_buf,
      }



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
            line = (line ~= "" and ref.data.prefix .. line) or "",
            untangled = it,
            insert = true,
          })
          table.insert(l.tangled, new_node)
        end
      end

    end


    return start_buf, end_buf, insert_after
  end

  if buf_vars[bufname] then
    buf_asm = buf_vars[bufname].buf_asm
    start_buf = buf_vars[bufname].start_buf
    end_buf = buf_vars[bufname].end_buf

    untangled_ll = asm_namespaces[buf_asm].untangled_ll
    sections_ll = asm_namespaces[buf_asm].sections_ll
    tangled_ll = asm_namespaces[buf_asm].tangled_ll
    root_set = asm_namespaces[buf_asm].root_set
    parts_ll = asm_namespaces[buf_asm].parts_ll

    bufs_set = asm_namespaces[buf_asm].bufs_set


    bufs_set[buf] = { start_buf, end_buf }


  else
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, true)


    asm_namespaces[buf] = {
      untangled_ll = {},
      tangled_ll = {},
      sections_ll = {},
      root_set = {},
      parts_ll = {},
      bufs_set = {},

    }

    untangled_ll = asm_namespaces[buf].untangled_ll
    sections_ll = asm_namespaces[buf].sections_ll
    tangled_ll = asm_namespaces[buf].tangled_ll
    root_set = asm_namespaces[buf].root_set
    parts_ll = asm_namespaces[buf].parts_ll

    bufs_set = asm_namespaces[buf].bufs_set


    start_buf = linkedlist.push_back(untangled_ll, {
      linetype = LineType.BUF_DELIM,
      buf = buf,
      str = "START " .. buf,
    })

    end_buf = linkedlist.push_back(untangled_ll, {
      linetype = LineType.BUF_DELIM,
      buf = buf,
      str = "END " .. buf,
    })

    linkedlist.push_back(parts_ll, {
      start_buf = start_buf,
      end_buf = end_buf,
      name = vim.api.nvim_buf_get_name(buf),
    })


    bufs_set[buf] = { start_buf, end_buf }



    local linecount = vim.api.nvim_buf_line_count(buf)
    local insert_after = start_buf
    for i=0,linecount-1 do
      local line = vim.api.nvim_buf_get_lines(buf, i, i+1, true)[1]
      start_buf, end_buf, insert_after = insert_line(i, line, start_buf, end_buf, insert_after)
    end

    for name, root in pairs(root_set) do
      local start_file = root.start_file
      local end_file = root.end_file

      local it = start_file

      while it ~= end_file do
        it.data.insert = nil
        it = it.next
      end
    end

    buf_vars[bufname] = {
      buf_asm = buf_asm,
      start_buf = start_buf,
      end_buf = end_buf,
    }

  end

  for buf, sent in pairs(bufs_set) do
    local start_buf, end_buf = unpack(sent)
    local lnum = 1
    local it = start_buf.next
    while it ~= end_buf do
      it.data.lnum = lnum
      it.data.buf = buf
      lnum = lnum + 1
      it = it.next
    end
  end

  for name, root in pairs(root_set) do
    local start_file = root.start_file
    local end_file = root.end_file

    local source_lines = {}

    local it = start_file
    while it ~= end_file do
      local line = it.data
      if line.linetype == LineType.TANGLED then
        table.insert(source_lines, line.line)
      end
      it = it.next
    end

    root.sources = table.concat(source_lines, "\n")
  end

  backbuf[buf] = true

  lang[buf] = ext

  local local_parser = vim.treesitter.get_parser()
  local_parser._callbacks.changedtree = {}
  local_parser._callbacks.bytes = {}

  for name, root in pairs(root_set) do
    local cur_tree, tree_changes = root.parser:parse(nil, root.sources)
    -- print("initial")
    -- print(vim.inspect(sources[buf]))
    -- print(cur_tree[1]:root():sexpr())
    root.tree = cur_tree
  end


  local lookups = {}
  lookups[buf] = {}

  for name, root in pairs(root_set) do
    local start_file = root.start_file
    local end_file = root.end_file
    local tree = root.tree

    local tangle_lnum = 1

    local it = start_file
    while it ~= end_file do
      local line = it.data
      if line.linetype == LineType.TANGLED then
        local lookup_buf = line.untangled.data.buf
        if lookup_buf then
          lookups[lookup_buf] = lookups[lookup_buf] or {}
          local lookup = lookups[lookup_buf]
          lookup[line.untangled.data.lnum] = { tangle_lnum, string.len(line.prefix), root }
        end
        tangle_lnum = tangle_lnum + 1
      end

      it = it.next
    end
  end


  for buf, lookup in pairs(lookups) do
    backlookup[buf] = lookup
  end

  states[bufname] = vim.api.nvim_buf_get_lines(0, 0, -1, true)

  for name, root in pairs(root_set) do
    local start_file = root.start_file
    local end_file = root.end_file

    local source_lines = {}

    local it = start_file
    while it ~= end_file do
      local line = it.data
      if line.linetype == LineType.TANGLED then
        table.insert(source_lines, line.line)
      end
      it = it.next
    end

    for _, cbs in ipairs(cbs_init) do
      cbs(buf, root.filename, ext, source_lines)
    end

  end
  init_events = {}


  vim.api.nvim_buf_attach(buf, true, {
    on_bytes = function(...)
      local _, _, _, start_row, start_col, _, end_row, end_col, _, new_end_row, new_end_col, _ = unpack({...})
      local state = states[bufname]

      if end_row == 0 then
        if start_row+1 <= #state then
          state[start_row+1] = state[start_row+1]:sub(1, start_col) .. state[start_row+1]:sub(start_col+end_col+1)
        end
      else

        local beg = state[start_row+1]:sub(1, start_col)
        local rest = (state[start_row+end_row+1] or ""):sub(end_col+1)

        table.remove(state, start_row+end_row+1)

        for i=1,end_row-1 do
          table.remove(state, start_row+2)
        end
        state[start_row+1] = beg .. rest
      end

      if new_end_row == 0 then
        local line = get_line(buf, start_row)
        for i=string.len(line),start_col+new_end_col do
          line = line .. " "
        end

        state[start_row+1] = state[start_row+1]:sub(1, start_col) .. line:sub(start_col+1, start_col+new_end_col) .. state[start_row+1]:sub(start_col+1)
      else
        for i=1,new_end_row-1 do
          local line = get_line(buf, start_row+i)
          table.insert(state, i+start_row+1, line)
        end

        local line = get_line(buf, start_row)
        local beg = (state[start_row+1] or ""):sub(1, start_col)
        local rest = (state[start_row+1] or ""):sub(start_col+1)
        state[start_row+1] = beg .. line:sub(start_col+1)

        local line = get_line(buf, start_row+new_end_row)
        table.insert(state, start_row+new_end_row+1, line:sub(1, new_end_col) .. rest)
      end


      states[bufname] = state

      local firstline = start_row
      local lastline = start_row + end_row + 1
      local new_lastline = start_row + new_end_row + 1

      local delete_this = start_buf.next
      for _=1,lastline-1 do
        delete_this = delete_this.next
      end

      for _=firstline,lastline-1 do
        local cur_delete = delete_this
        if not cur_delete or cur_delete == end_buf then break end
        delete_this = delete_this.prev

        if cur_delete.data.linetype == LineType.SECTION then
          local insert_after = cur_delete
          if cur_delete.data.op == "=" then
            linkedlist.remove(tangled_ll, cur_delete.data.tangled[1])
            linkedlist.remove(tangled_ll, cur_delete.data.extra_tangled)

            local root = root_set[cur_delete.data.str]
            if root and root.filename then
              table.insert(deinit_events, root.filename)
            end

            root_set[cur_delete.data.str] = nil

          else
            for _, ref in ipairs(cur_delete.data.tangled) do
              linkedlist.remove(tangled_ll, ref)
            end
          end

          local it = insert_after and insert_after.next
          while it ~= end_buf do
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

                  -- linkedlist.remove(tangled_ll, to_delete)
                  to_delete.data.remove = true

                  copy = copy.next
                end
              end

            else
              if cur_delete.data.tangled then
                for _, ref in ipairs(cur_delete.data.tangled) do
                  ref.data.remove = true
                end
              end

            end

            it = it.next
          end

          if sections_ll[cur_delete.data.str] then
            local it = sections_ll[cur_delete.data.str].head
            while it do
              if it.data == cur_delete then
                linkedlist.remove(sections_ll[cur_delete.data.str], it)
                break
              end
              it = it.next
            end

            if linkedlist.get_size(sections_ll[cur_delete.data.str]) == 0 then
              sections_ll[cur_delete.data.str] = nil
            end
          end

          if cur_delete then
            linkedlist.remove(untangled_ll, cur_delete)
          end

          local it = insert_after and insert_after.next
          while it ~= end_buf do
            local insert_after = it.prev
            if it.data.linetype == LineType.SECTION then
              break
            elseif it.data.linetype == LineType.REFERENCE then
              local l = it.data
              local name = l.str
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
                    line = (line ~= "" and ref.data.prefix .. line) or "",
                    untangled = it,
                    insert = true,
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

              -- linkedlist.remove(tangled_ll, to_delete)
              to_delete.data.remove = true

              copy = copy.next
            end
          end

        elseif cur_delete == start_buf.next and cur_delete.data.linetype == LineType.ASSEMBLY then
          if buf_asm then
            local delete_this = start_buf.next
            while delete_this ~= end_buf do
              local cur_delete = delete_this
              if not cur_delete then break end
              delete_this = delete_this.next

              if cur_delete.data.linetype == LineType.SECTION then
                local insert_after = cur_delete
                if cur_delete.data.op == "=" then
                  linkedlist.remove(tangled_ll, cur_delete.data.tangled[1])
                  linkedlist.remove(tangled_ll, cur_delete.data.extra_tangled)

                  local root = root_set[cur_delete.data.str]
                  if root and root.filename then
                    table.insert(deinit_events, root.filename)
                  end

                  root_set[cur_delete.data.str] = nil

                else
                  for _, ref in ipairs(cur_delete.data.tangled) do
                    linkedlist.remove(tangled_ll, ref)
                  end
                end

                if sections_ll[cur_delete.data.str] then
                  local it = sections_ll[cur_delete.data.str].head
                  while it do
                    if it.data == cur_delete then
                      linkedlist.remove(sections_ll[cur_delete.data.str], it)
                      break
                    end
                    it = it.next
                  end

                  if linkedlist.get_size(sections_ll[cur_delete.data.str]) == 0 then
                    sections_ll[cur_delete.data.str] = nil
                  end
                end


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

                    -- linkedlist.remove(tangled_ll, to_delete)
                    to_delete.data.remove = true

                    copy = copy.next
                  end
                end

              else
                if cur_delete.data.tangled then
                  for _, ref in ipairs(cur_delete.data.tangled) do
                    ref.data.remove = true
                  end
                end

              end

            end

            local it = parts_ll.head
            local cur_name = vim.api.nvim_buf_get_name(0)
            while it do
              if it.data.name == buf_name then
                linkedlist.remove(parts_ll, it)
                break
              end
              it = it.next
            end

          end

          local name = buf
          asm_namespaces[buf] = nil
          local old_untangled_ll = untangled_ll

          local check_links = false
          if not asm_namespaces[name] then
            asm_namespaces[name] = {
              untangled_ll = {},
              tangled_ll = {},
              sections_ll = {},
              root_set = {},
              parts_ll = {},
              bufs_set = {},

            }

            check_links = true
          end

          untangled_ll = asm_namespaces[name].untangled_ll
          sections_ll = asm_namespaces[name].sections_ll
          tangled_ll = asm_namespaces[name].tangled_ll
          root_set = asm_namespaces[name].root_set
          parts_ll = asm_namespaces[name].parts_ll
          bufs_set = asm_namespaces[name].bufs_set

          buf_asm = name

          if type(name) ~= "number" and check_links then
            path = vim.fn.fnamemodify(path, ":p")
            local parts = vim.split(vim.fn.glob(path .. assembly_tail .. ".*.t"), "\n")
            link_name = vim.fn.fnamemodify(link_name, ":p")

            for _, part in ipairs(parts) do
            	if link_name ~= part then
            		local f = io.open(part, "r")
            		local origin_path
            		if f then
            		  origin_path = f:read("*line")
            		  f:close()
            		end

                if origin_path then
                  local f = io.open(origin_path, "r")
                  if f then
                    local start_buf = linkedlist.push_back(untangled_ll, {
                      linetype = LineType.BUF_DELIM,
                      str = "START " .. origin_path,
                    })

                    local end_buf = linkedlist.push_back(untangled_ll, {
                      linetype = LineType.BUF_DELIM,
                      str = "END " .. origin_path,
                    })

                    linkedlist.push_back(parts_ll, {
                      start_buf = start_buf,
                      end_buf = end_buf,
                      name = origin_path,
                    })

                    buf_vars[string.lower(origin_path)] = {
                      buf_asm = buf_asm,
                      start_buf = start_buf,
                      end_buf = end_buf,
                    }

                  	local lnum = 1
                    local insert_after = start_buf
                  	while true do
                  		local line = f:read("*line")
                  		if not line then break end
                      start_buf, end_buf, insert_after = insert_line(nil, line, start_buf, end_buf, insert_after)
                  		lnum = lnum + 1
                  	end
                  	f:close()
                  end

                end
            	end
            end

          end

          local part_after = parts_ll.head
          local cur_name = vim.api.nvim_buf_get_name(0)
          while part_after do
            if part_after.data.name > cur_name then
              break
            end
            part_after = part_after.next
          end

          local new_start_buf, new_end_buf
          if not part_after then
            new_start_buf = linkedlist.push_back(untangled_ll, {
              linetype = LineType.BUF_DELIM,
              buf = buf,
              str = "START " .. bufname,
            })

            new_end_buf = linkedlist.push_back(untangled_ll, {
              linetype = LineType.BUF_DELIM,
              buf = buf,
              str = "END " .. bufname,
            })

            linkedlist.push_back(parts_ll, {
              start_buf = new_start_buf,
              end_buf = new_end_buf,
              name = vim.api.nvim_buf_get_name(buf),
            })

          else
            local end_buf_after = part_after.data.start_buf

            new_start_buf = linkedlist.insert_before(untangled_ll, end_buf_after, {
              linetype = LineType.BUF_DELIM,
              buf = buf,
              str = "START " .. buf,
            })


            new_end_buf = linkedlist.insert_after(untangled_ll, new_start_buf, {
              linetype = LineType.BUF_DELIM,
              buf = buf,
              str = "END " .. buf,
            })

            linkedlist.insert_before(parts_ll, part_after, {
              start_buf = start_buf,
              end_buf = end_buf,
              name = cur_name
            })

          end

          local transfer_this = start_buf.next
          local dest = new_start_buf
          while transfer_this ~= end_buf do
            dest = linkedlist.insert_after(untangled_ll, dest, transfer_this.data)
            local delete_this = transfer_this
            transfer_this = transfer_this.next
            linkedlist.remove(old_untangled_ll, delete_this)
          end

          linkedlist.remove(old_untangled_ll, start_buf)
          linkedlist.remove(old_untangled_ll, end_buf)
          old_untangled_ll = nil
          start_buf = new_start_buf
          end_buf = new_end_buf

          bufs_set[buf] = { start_buf, end_buf }


          insert_after = start_buf.next

          do
            local it = start_buf.next.next
            while it ~= end_buf do
              local insert_after = it.prev
              if it.data.linetype == LineType.ASSEMBLY then
              elseif it.data.linetype == LineType.SECTION then
                local l = it.data
                local insert_after = it
                local op = l.op
                local name = l.str
                local it = insert_after and insert_after.prev
                while it ~= start_buf do
                  if it.data.linetype == LineType.SECTION and it.data.str == name then
                    break
                  end
                  it = it.prev
                end

                local section
                if it ~= start_buf then
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

                  local filename
                  local buf_asm = (buf_vars[bufname] and buf_vars[bufname].buf_asm) or ""

                  local parent_assembly
                  parent_assembly = vim.fn.fnamemodify(buf_asm, ":h")

                  local root_name = name
                  if name == "*" then
                    root_name = "tangle/" .. vim.fn.fnamemodify(bufname, ":t:r")
                  else
                  	if string.find(name, "/") then
                  		root_name = name
                  	else
                  		root_name = "tangle/" .. name
                  	end
                  end

                  local cur_dir = vim.fn.fnamemodify(bufname, ":h")
                  filename = cur_dir .. "/" .. parent_assembly .. "/" .. root_name
                  filename = string.lower(filename:gsub("\\", "/"))


                  root_set[l.str] = {
                    filename = filename,
                    start_file = start_file,
                    end_file = end_file,
                    parser = vim._create_ts_parser(ext),
                    tree = nil,
                  }

                  table.insert(init_events, l.str)

                end


              elseif it.data.linetype == LineType.REFERENCE then
                local l = it.data
                local name = l.str
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
                      line = (line ~= "" and ref.data.prefix .. line) or "",
                      untangled = it,
                      insert = true,
                    })
                    table.insert(l.tangled, new_node)
                  end
                end

              end

              it = it.next
            end
          end

          cur_delete = start_buf.next
          delete_this = cur_delete.next

          buf_vars[bufname] = {
            buf_asm = buf_asm,
            start_buf = start_buf,
            end_buf = end_buf,
          }


        else
          if cur_delete.data.tangled then
            for _, ref in ipairs(cur_delete.data.tangled) do
              ref.data.remove = true
            end
          end

        end


        if cur_delete then
          linkedlist.remove(untangled_ll, cur_delete)
        end

      end

      local insert_after = start_buf
      for _=1,firstline do
        insert_after = insert_after.next
      end

      for i=firstline,new_lastline-1 do
        local line = state[i+1]
        if line then
          start_buf, end_buf, insert_after = insert_line(i, line, start_buf, end_buf, insert_after)
        end
      end


      for name, root in pairs(root_set) do
        local parser = root.parser
        local start_file = root.start_file
        local end_file = root.end_file
        local tree = root.tree

        local it = start_file
        local lrow = 1
        local source_len = 0

        while it ~= end_file do
          if it.data.linetype == LineType.TANGLED then
            if it.data.remove then
              if not it.data.insert then
                local start_byte = source_len
                local start_col = 0
                local start_row = lrow-1
                local old_row = 1
                local new_row = 0
                local old_byte = string.len(it.data.line) + 1
                local new_byte = 0
                local old_end_col = 0
                local new_end_col = 0

                if tree then
                  tree:edit(start_byte,start_byte+old_byte,start_byte+new_byte,
                    start_row, start_col,
                    start_row+old_row, old_end_col,
                    start_row+new_row, new_end_col)
                  for _, cbs in ipairs(cbs_change) do
                    cbs(buf, root.filename,
                      start_byte,old_byte,new_byte,
                      start_row, start_col,
                      old_row, old_end_col,
                      new_row, new_end_col,
                      { it.data.line })
                  end

                end

              end
              local tmp = it
              it = it.next
              linkedlist.remove(tangled_ll, tmp)

            elseif it.data.insert then
              local start_byte = source_len
              local start_col = 0
              local start_row = lrow-1
              local old_row = 0
              local new_row = 1
              local old_byte = 0
              local new_byte = string.len(it.data.line) + 1
              local old_end_col = 0
              local new_end_col = 0

              if tree then
                tree:edit(start_byte,start_byte+old_byte,start_byte+new_byte,
                  start_row, start_col,
                  start_row+old_row, old_end_col,
                  start_row+new_row, new_end_col)
                for _, cbs in ipairs(cbs_change) do
                  cbs(buf, root.filename,
                    start_byte,old_byte,new_byte,
                    start_row, start_col,
                    old_row, old_end_col,
                    new_row, new_end_col,
                    { it.data.line })
                end

              end

              if source_len == 0 then
                source_len = source_len + string.len(it.data.line)
              else
                source_len = source_len + string.len(it.data.line) + 1
              end

              it.data.insert = nil
              lrow = lrow + 1
              it = it.next
            else
              if source_len == 0 then
                source_len = source_len + string.len(it.data.line)
              else
                source_len = source_len + string.len(it.data.line) + 1
              end

              lrow = lrow + 1
              it = it.next
            end
          else
              it = it.next
          end
        end
      end


      -- @display_tangle_output
      -- @display_untangle_output

      for buf, sent in pairs(bufs_set) do
        local start_buf, end_buf = unpack(sent)
        local lnum = 1
        local it = start_buf.next
        while it ~= end_buf do
          it.data.lnum = lnum
          it.data.buf = buf
          lnum = lnum + 1
          it = it.next
        end
      end

      for name, root in pairs(root_set) do
        local start_file = root.start_file
        local end_file = root.end_file

        local source_lines = {}

        local it = start_file
        while it ~= end_file do
          local line = it.data
          if line.linetype == LineType.TANGLED then
            table.insert(source_lines, line.line)
          end
          it = it.next
        end

        root.sources = table.concat(source_lines, "\n")
      end
      for name, root in pairs(root_set) do
        local cur_tree, tree_changes = root.parser:parse(root.tree,root.sources)
        root.tree = cur_tree
      end

      local lookups = {}
      lookups[buf] = {}

      for name, root in pairs(root_set) do
        local start_file = root.start_file
        local end_file = root.end_file
        local tree = root.tree

        local tangle_lnum = 1

        local it = start_file
        while it ~= end_file do
          local line = it.data
          if line.linetype == LineType.TANGLED then
            local lookup_buf = line.untangled.data.buf
            if lookup_buf then
              lookups[lookup_buf] = lookups[lookup_buf] or {}
              local lookup = lookups[lookup_buf]
              lookup[line.untangled.data.lnum] = { tangle_lnum, string.len(line.prefix), root }
            end
            tangle_lnum = tangle_lnum + 1
          end

          it = it.next
        end
      end


      for buf, lookup in pairs(lookups) do
        backlookup[buf] = lookup
      end


      for _, name in ipairs(init_events) do
        local root = root_set[name]
        if root then
          local start_file = root.start_file
          local end_file = root.end_file

          local source_lines = {}

          local it = start_file
          while it ~= end_file do
            local line = it.data
            if line.linetype == LineType.TANGLED then
              table.insert(source_lines, line.line)
            end
            it = it.next
          end

          for _, cbs in ipairs(cbs_init) do
            cbs(buf, root.filename, ext, source_lines)
          end

        end
      end
      init_events = {}

      for _, fn in ipairs(deinit_events) do
        for _, cbs in ipairs(cbs_deinit) do
          cbs(buf, fn, ext)
        end
      end

    end,
  })
end

function M.show_state()
  local bufname = string.lower(vim.api.nvim_buf_get_name(0))
  local state = states[bufname]

  for i, line in ipairs(state) do
    print(i, vim.inspect(line))
  end
end
function M.print_lookup()
  print("backlookup " .. vim.inspect(backlookup))
end

function M.print_tangled()
  for buf, namespace in pairs(asm_namespaces) do
    print("BUF " .. buf)
    local tangled_ll = namespace.tangled_ll

    for line in linkedlist.iter(tangled_ll) do
      print(getLinetype(line.linetype) .. " " .. vim.inspect(line.line))
    end
  end
end

function M.print_untangled()
  for buf, namespace in pairs(asm_namespaces) do
    print("BUF " .. buf)
    local untangled_ll = namespace.untangled_ll

    for line in linkedlist.iter(untangled_ll) do
      print(getLinetype(line.linetype) .. " " .. vim.inspect(line.str))
    end
  end
end
function M.lookup(buf, lnum)
  local lookup = backlookup[buf]
  local info = lookup[lnum]
  local lnum, len_prefix, root = unpack(info)
  return lnum, len_prefix, root.filename
end
function getLinetype(linetype)
  if linetype == LineType.TEXT then return "TEXT"
  elseif linetype == LineType.REFERENCE then return "REFERENCE"
  elseif linetype == LineType.SECTION then return "SECTION"
  elseif linetype == LineType.BUF_DELIM then
    return "BUFDELIM"

  elseif linetype == LineType.ASSEMBLY then return "ASSEMBLY"

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
        prefix = after_this.data.prefix,
        untangled = node
      })
      l.tangled = l.tangled or {}
      table.insert(l.tangled, section_sentinel)
      after_this = section_sentinel

      node = node.next
      while node do
        if node.data.linetype == LineType.TEXT then
          local l = { 
            linetype = LineType.TANGLED, 
            prefix = prefix,
            line = prefix .. node.data.str,
            insert = true,
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
        prefix = after_this.data.prefix,
        untangled = node
      })
      l.tangled = l.tangled or {}
      table.insert(l.tangled, section_sentinel)
      after_this = section_sentinel

      node = node.next
      while node do
        if node.data.linetype == LineType.TEXT then
          local l = { 
            linetype = LineType.TANGLED, 
            prefix = prefix,
            line = prefix .. node.data.str,
            insert = true,
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
        prefix = after_this.data.prefix,
        untangled = node
      })
      l.tangled = l.tangled or {}
      table.insert(l.tangled, section_sentinel)
      after_this = section_sentinel

      node = node.next
      while node do
        if node.data.linetype == LineType.TEXT then
          local l = { 
            linetype = LineType.TANGLED, 
            prefix = prefix,
            line = prefix .. node.data.str,
            insert = true,
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

function M.go_down()
  local bufname = string.lower(vim.api.nvim_buf_get_name(buf))

  local buf_asm = buf_vars[bufname].buf_asm
  local start_buf = buf_vars[bufname].start_buf
  local end_buf = buf_vars[bufname].end_buf

  local parts_ll = asm_namespaces[buf_asm].parts_ll

  local lnum, _ = unpack(vim.api.nvim_win_get_cursor(0))

  local search = start_buf
  for _=1,lnum do
    search = search.next
  end

  if search.data.linetype ~= LineType.REFERENCE then
    print("No reference under cursor.")
    return
  end

  local reference_name = search.data.str

  local references = {}
  for part in linkedlist.iter(parts_ll) do
    local start_part = part.start_buf
    local end_part = part.end_buf
    local it = start_part.next
    local part_lnum = 1
    while it and it ~= end_part do
      if it.data.linetype == LineType.SECTION and it.data.str == reference_name then
        table.insert(references, {
          filename = part.name,
          lnum = part_lnum,
        })

      end
      part_lnum = part_lnum + 1
      it = it.next
    end
  end

  vim.fn.setqflist(references)

  if #references == 0 then
    print("No reference found.")
  else
    if references[1].filename ~= buf then
      vim.api.nvim_command("e " .. references[1].filename)
    end
    vim.api.nvim_win_set_cursor(0, {references[1].lnum, 0})
  end
end

function M.go_up()
  local bufname = string.lower(vim.api.nvim_buf_get_name(buf))

  local buf_asm = buf_vars[bufname].buf_asm
  local start_buf = buf_vars[bufname].start_buf
  local end_buf = buf_vars[bufname].end_buf

  local parts_ll = asm_namespaces[buf_asm].parts_ll

  local lnum, _ = unpack(vim.api.nvim_win_get_cursor(0))

  local search = start_buf
  for _=1,lnum do
    search = search.next
  end

  local section_name
  while search do
    if search.data.linetype == LineType.SECTION then
      section_name = search.data.str
      break
    end
    search = search.prev
  end

  if not section_name then
    return
  end

  local references = {}
  for part in linkedlist.iter(parts_ll) do
    local start_part = part.start_buf
    local end_part = part.end_buf
    local it = start_part.next
    local part_lnum = 1
    while it and it ~= end_part do
      if it.data.linetype == LineType.REFERENCE and it.data.str == section_name then
        table.insert(references, {
          filename = part.name,
          lnum = part_lnum,
        })

      end
      part_lnum = part_lnum + 1
      it = it.next
    end

  end

  vim.fn.setqflist(references)

  if #references == 0 then
    print("No reference found.")
  else
    if references[1].filename ~= buf then
      vim.api.nvim_command("e " .. references[1].filename)
    end
    vim.api.nvim_win_set_cursor(0, {references[1].lnum, 0})
  end
end

function M._on_line(...)
  local _, _, buf, line = unpack({...})
  if backbuf[buf] then
    local lookup = backlookup[buf]

    if lookup and lookup[line+1] then
      local tline = line
      local line, indent, root = unpack(lookup[line+1])
      local tstree = root.tree
      local sources = root.sources
      line = line - 1
      local self = vim.treesitter.highlighter.active[buf]

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
        state.iter = highlighter_query:query():iter_captures(root_node, sources, line, root_end_row + 1)
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

      local linetype
      if string.match(curline, "^@[^@]%S*[+-]?=%s*$") then
        linetype = LineType.SECTION
      elseif string.match(curline, "^%s*@[^@]%S*%s*$") then
        linetype = LineType.REFERENCE
      elseif string.match(curline, "^##%S+$") then
        linetype = LineType.ASSEMBLY
      end

      local hl_group
      if linetype == LineType.REFERENCE then
        hl_group = "TSString"
      elseif linetype == LineType.ASSEMBLY then
        hl_group = "TSString"
      else
        hl_group = "TSString"
      end

      vim.api.nvim_buf_set_extmark(buf, ns, line, 0, { 
          end_col = string.len(curline),
          hl_group = hl_group,
          ephemeral = true,
          priority = 100 -- Low but leaves room below
      })

    end

  -- @test_override
  else
    highlighter._on_line(...)
  end

end

function M.override()
  local nss = vim.api.nvim_get_namespaces()
  ns = nss["treesitter/highlighter"]

  vim.api.nvim_set_decoration_provider(ns, {
    on_buf = highlighter._on_buf,
    on_line = M._on_line,
    on_win = highlighter._on_win,
  })

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
end

function M.register(opts)
  if opts and type(opts) == "table" then
    if opts.on_change then
      table.insert(cbs_change, opts.on_change)
    end

    if opts.on_init then
      table.insert(cbs_init, opts.on_init)
    end

    if opts.on_deinit then
      table.insert(cbs_deinit, opts.on_deinit)
    end

  end
end

function M.reverse_lookup(fname, lnum)
  local bufname = vim.api.nvim_buf_get_name(0)
  bufname = string.lower(bufname)
  if buf_vars[bufname] then
    local buf_asm = buf_vars[bufname].buf_asm
    local root_set = asm_namespaces[buf_asm].root_set

    for name, root in pairs(root_set) do
      if root.filename == fname then
        local line = root.start_file
        local i = 0
        while i < lnum do
          if line == root.end_file then
            line = nil
            break
          end
          line = line.next

          if line.data.linetype ~= LineType.SENTINEL then
            i = i + 1
          end
        end

        if line then
          local untangled = line.data.untangled
          if untangled then
            return untangled.data.lnum, untangled.data.buf
          end
        end
        return nil
      end
    end
  end
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
return M
