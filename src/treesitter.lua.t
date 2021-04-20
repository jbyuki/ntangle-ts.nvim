##ntangle-ts
@get_language_extension+=
local bufname = vim.api.nvim_buf_get_name(0)
local ext = vim.fn.fnamemodify(bufname, ":e:e:r")

@create_parser_for_buffer+=
local parser = vim.treesitter.get_parser(buf, ext)

@create_highlighter_for_buffer+=
vim.treesitter.highlighter.new(parser, {})

@set_filetype_to_original_language+=
vim.api.nvim_command("set ft=" .. ext)
