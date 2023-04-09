-- Generated using ntangle.nvim
local M = {}
local tangled = {}

local ntangle = require"ntangle"

local tangled_content = {}

function M.attach(buf)
	local buf_fn

	local buf = buf or vim.api.nvim_get_current_buf()

	tangled[buf] = true

	local scratch = vim.api.nvim_create_buf(true, true)
	vim.bo[scratch].buftype = "nowrite"

	vim.api.nvim_buf_attach(scratch, 0, {
	  on_extmark = function(_, _, info)
			local tangled = tangled_content[buf]
			local start_row, start_col, details = unpack(info)
			local tangled_it
			for name, root in pairs(tangled.roots) do
				local start_root = root.tangled[1]
				local end_root = root.tangled[2]
				tangled_it = start_root
				while tangled_it and tangled_it ~= end_root do
					if tangled_it.data.linetype ~= ntangle.LineType.SENTINEL then
						if tangled_it.data.lnum == start_row then
							break
						end
					end
					tangled_it = tangled_it.next
				end
				break
			end

			if tangled_it then
				local untangled = tangled_it.data.untangled

				local lnum
				for part in ntangle.linkedlist.iter(tangled.parts_ll) do
					local part_lnum = 0
					local it = part.start_part
					while it and it ~= part.end_part do
						if it.data.linetype ~= ntangle.LineType.SENTINEL then
							if it == untangled then
								lnum = part_lnum
								break
							end
							part_lnum = part_lnum + 1
						end
						it = it.next
					end

					if lnum then break end
				end

				if lnum then
					if details.end_row then
						local drow = details.end_row - start_row
						start_row = lnum
						details.end_row = lnum+drow
					else
						start_row = lnum
					end
				else
					start_row = nil
					details.end_row = nil
				end
			else
				start_row = nil
				details.end_row = nil
			end


			if details.end_row and details.end_row ~= start_row then
				return true
			end

			if start_row then
				local ns_id = details.ns_id
				details.ns_id = nil
				vim.api.nvim_buf_set_extmark(buf, ns_id, start_row, start_col, details)
			end
	    return true
	  end,
		on_clear_namespace = function(_, _, ns_id, line_start, line_end)
			vim.api.nvim_buf_clear_namespace(buf, ns_id, line_start, line_end)
			return true
		end
	})

	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, true)

	local filename = vim.api.nvim_buf_get_name(buf)
	local tangled = ntangle.tangle_lines(filename, lines, nil)

	for name, root in pairs(tangled.roots) do
		local lines = {}
		local it = root.tangled[1]
		while it and it ~= root.tangled[2] do
		  if it.data.linetype == ntangle.LineType.TANGLED then
		    table.insert(lines, it.data.str)
		  end
		  it = it.next
		end

		vim.api.nvim_buf_set_lines(scratch, 0, -1, true, lines)

		buf_fn = ntangle.get_origin(filename, tangled.asm, name)

		break
	end

	for name, root in pairs(tangled.roots) do
	  local lnum = 0
	  local it = root.tangled[1]
	  while it and it ~= root.tangled[2] do
	    if it.data.linetype ~= ntangle.LineType.SENTINEL then
	      it.data.lnum = lnum
	      it.data.root = name
	      lnum = lnum + 1
	    end
	    it = it.next
	  end
	end

	tangled_content[buf] = tangled



	vim.api.nvim_buf_set_name(scratch, buf_fn)

	vim.treesitter.highlighter._on_buf_line[buf] = function(buf, line)
		local tangled = tangled_content[buf]
		local jumplines = {}
		for part in ntangle.linkedlist.iter(tangled.parts_ll) do
			local part_lnum = 0
			local it = part.start_part
			while it and it ~= part.end_part do
				if it.data.linetype ~= ntangle.LineType.SENTINEL then
					if part_lnum == line then
						jumplines = it.data.tangled
						break
					end
					part_lnum = part_lnum + 1
				end
				it = it.next
			end

			if jumplines then break end
		end

		if #jumplines >= 1 then
			local jumpline = jumplines[1]
			if jumpline.data.lnum then
				return scratch, jumpline.data.lnum
			else
				return nil, nil
			end

		else
			return nil, nil
		end

	end

	vim.treesitter.highlighter._on_buf_list[buf] = { scratch }

	vim.lsp.util._on_buf_line[buf] = function(buf, line)
		local tangled = tangled_content[buf]
		local jumplines = {}
		for part in ntangle.linkedlist.iter(tangled.parts_ll) do
			local part_lnum = 0
			local it = part.start_part
			while it and it ~= part.end_part do
				if it.data.linetype ~= ntangle.LineType.SENTINEL then
					if part_lnum == line then
						jumplines = it.data.tangled
						break
					end
					part_lnum = part_lnum + 1
				end
				it = it.next
			end

			if jumplines then break end
		end

		if #jumplines >= 1 then
			local jumpline = jumplines[1]
			if jumpline.data.lnum then
				return scratch, jumpline.data.lnum
			else
				return nil, nil
			end

		else
			return nil, nil
		end

	end

	vim.lsp.util._on_buf[buf] = scratch

	vim.bo[scratch].filetype = "cpp"

	local opts = { buffer = buf }
	vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
	vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)


	vim.api.nvim_buf_attach(buf, false, {
		on_bytes = function(_, _, _, start_row, start_col, start_byte, old_end_row, old_end_col, old_end_byte, new_end_row, new_end_col, new_end_byte)
			local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, true)

			local filename = vim.api.nvim_buf_get_name(buf)
			local tangled = ntangle.tangle_lines(filename, lines, nil)

			for name, root in pairs(tangled.roots) do
				local lines = {}
				local it = root.tangled[1]
				while it and it ~= root.tangled[2] do
				  if it.data.linetype == ntangle.LineType.TANGLED then
				    table.insert(lines, it.data.str)
				  end
				  it = it.next
				end

				vim.api.nvim_buf_set_lines(scratch, 0, -1, true, lines)

				buf_fn = ntangle.get_origin(filename, tangled.asm, name)

				break
			end

			for name, root in pairs(tangled.roots) do
			  local lnum = 0
			  local it = root.tangled[1]
			  while it and it ~= root.tangled[2] do
			    if it.data.linetype ~= ntangle.LineType.SENTINEL then
			      it.data.lnum = lnum
			      it.data.root = name
			      lnum = lnum + 1
			    end
			    it = it.next
			  end
			end

			tangled_content[buf] = tangled



			local hl = vim.treesitter.highlighter.active[scratch]
			hl.tree:parse()


		end
	})

end

function M.detach(buf)
	assert(tangled[buf])
	tangled[buf] = nil
	vim.treesitter.highlighter._on_buf_line[buf] = nil

end

function M.version()
	return "0.0.1"
end
return M
