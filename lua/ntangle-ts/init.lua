-- Generated from attach.lua.t, debug.lua.t, init.lua.t, on_buf.lua.t, on_line.lua.t, on_win.lua.t, override_decoration_provider.lua.t using ntangle.nvim
local valid = {}

local ntangle = require"ntangle"

local backlookup = {}

local backbuf = {}

local later = {}

local highlighter = vim.treesitter.highlighter

local ns

local M = {}
function M.attach()
  local buf = vim.api.nvim_get_current_buf()
  
  if backbuf[buf] then
    return
  end
  
  highlighter.active[buf] = nil
  

  local parser = vim.treesitter.get_parser()
  parser._callbacks.changedtree = {}
  parser._callbacks.bytes = {}
  

  local lookup = {}
  local bufs = {}

  lookup = ntangle.tangle_to_buf(bufs)
  
  for _, unbuf in pairs(bufs) do
    backbuf[buf] = unbuf
    print(unbuf)
  end
  
  for buf, l in pairs(lookup) do
    backlookup[buf] = l
  end
  
  local ft = vim.api.nvim_buf_get_option(buf, "ft")
  local parser = vim.treesitter.get_parser(backbuf[buf], ft)
  highlighter.new(parser)
  

  valid[buf] = true

  vim.api.nvim_buf_attach(buf, true, {
    on_bytes = function(...)
      valid[buf] = false
      vim.schedule(function()
        lookup = ntangle.tangle_to_buf(bufs)
        
        valid[buf] = true
        for buf, l in pairs(lookup) do
          backlookup[buf] = l
        end
        
        parser:parse()
        if #later[buf] > 0 then
          local start_row = later[buf][1]
          local end_row = later[buf][1]
          for _, row in ipairs(later[buf]) do
            start_row = math.min(start_row, row)
            end_row = math.max(end_row, row)
          end
        
          later[buf] = {}
          vim.api.nvim__buf_redraw_range(buf, start_row, end_row+1)
        end
      end)
    end
  })
end

function M.print_lookup()
  print("backlookup " .. vim.inspect(backlookup))
end
function M._on_buf(...)
end
function M._on_line(...)
  local _, _, buf, line = unpack({...})
  if backbuf[buf] then
    if valid[buf] then
      local unbuf = backbuf[buf]
      local hler = highlighter.active[unbuf]
      
      local lookup = backlookup[unbuf]
      
      if lookup[line+1] then
        local tline = line
        local line, indent = unpack(lookup[line+1])
        line = line - 1
        local self = hler
        self:reset_highlight_state()
        
        self.tree:for_each_tree(function(tstree, tree)
          if not tstree then return end
        
          local root_node = tstree:root()
          local root_start_row, _, root_end_row, _ = root_node:range()
        
          -- Only worry about trees within the line range
          if root_start_row > line or root_end_row < line then return end
        
          local state = self:get_highlight_state(tstree)
          local highlighter_query = self:get_query(tree:lang())
        
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
        end, true)
        
      else
        local curline = vim.api.nvim_buf_get_lines(buf, line, line+1, true)[1]
        
        vim.api.nvim_buf_set_extmark(buf, ns, line, 0, { 
            end_line = tline, end_col = string.len(curline),
            hl_group = "String",
            ephemeral = true,
            priority = 100 -- Low but leaves room below
        })
        
      end
    else
      later[buf] = later[buf] or {}
      table.insert(later[buf], line)
      
    end
  
  -- @test_override
  else
    highlighter._on_line(...)
  end
  
end

function M._on_win(...)
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
    on_win = M._on_win,
  })
end

return M
