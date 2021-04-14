-- Generated from attach.lua.t, debug.lua.t, hl_cache.lua.t, init.lua.t, on_buf.lua.t, on_line.lua.t, on_win.lua.t, override_decoration_provider.lua.t, parser.lua.t using ntangle.nvim
local ntangle = require"ntangle"

local backlookup = {}

local backbuf = {}

local test_buf = vim.api.nvim_create_buf(false, true)
print("created test buf " .. test_buf)

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

  lookup = ntangle.tangle_to_table(bufs)
  
  backbuf[buf] = true
  
  local ft = vim.api.nvim_buf_get_option(buf, "ft")
  local parser = vim._create_ts_parser(ft)
  lang[buf] = ft
  
  
  local local_parser = vim.treesitter.get_parser()
  local_parser._callbacks.changedtree = {}
  local_parser._callbacks.bytes = {}
  local fn
  for fni, b in pairs(bufs) do fn = fni break end
  sources[buf] = table.concat(bufs[fn], "\n")
  trees[buf] = parser:parse(nil, sources[buf])
  
  backlookup[buf] = lookup[fn]

  vim.api.nvim_buf_attach(buf, true, {
    on_bytes = function(...)
      lookup = ntangle.tangle_to_table(bufs)
      

      local fn
      for fni, b in pairs(bufs) do fn = fni break end
      sources[buf] = table.concat(bufs[fn], "\n")
      trees[buf] = parser:parse(nil, sources[buf])
      
      backlookup[buf] = lookup[fn]
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
    on_win = M._on_win,
  })
end

return M
