##ntangle-ts
@create_parser_for_untangled+=
local ft = vim.api.nvim_buf_get_option(buf, "ft")
local parser = vim._create_ts_parser(ft)
@save_buffer_language

@script_variables+=
local trees = {}
local sources = {}

@parse_everything_again+=
trees[buf] = parser:parse(nil, sources[buf])

@script_variables+=
local lang = {}

@save_buffer_language+=
lang[buf] = ft

@mutate_highlighter_for_ntangle+=
local local_parser = vim.treesitter.get_parser()
local_parser._callbacks.changedtree = {}
local_parser._callbacks.bytes = {}
