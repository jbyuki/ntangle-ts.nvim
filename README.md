ntangle-ts
==========

Experimental plugin to support parsing of tangled source code with treesitter.

How?
====

Parse in different buffer:
  * can't copy extmarks (ephemeral)
  * override decoration provider (most promising)
    * Probably need incremental tangling for speed

Parse in same buffer:
  * not out-of-order parsing in treesitter
  * It doesn't seem to be possible: [Issue](https://github.com/tree-sitter/tree-sitter/issues/1026)

Blinking issues
===============

It's almost working except for blinking issues. The reason is that it has the following execution order:

```
on_bytes -> redraw -> nvim_buf_set_lines (through vim.schedule from on_bytes) -> redraw (through nvim__buf_redraw_range)
```

Possible solution:
  * use string instead of separate buffer (slow?)
  * partially syntax highlight in initial redraw using previous syntax information (still blinking)
