ntangle-ts
==========

Experimental plugin to support parsing of tangled source code with treesitter.

* **Default**

<img src="https://i.postimg.cc/J0K067gg/default.png" width="150">

* **Embedded parser**

<img src="https://i.postimg.cc/0Np8X2Kf/embed-parser.png" width="150">

The `else` keyword is not properly highlighted because it's just concatenating the text when parsing.

* **ntangle-ts**

<img src="https://i.postimg.cc/zXsYmYrP/ntangle-ts.png" width="150">

Everything is properly syntax highlighted.

How?
====

Parse in different buffer:
  * can't copy extmarks (ephemeral)
  * override decoration provider (most promising) **This approach is used**
    * Probably need incremental tangling for speed 

Parse in same buffer:
  * not out-of-order parsing in treesitter
  * It doesn't seem to be possible: [Issue](https://github.com/tree-sitter/tree-sitter/issues/1026)

Blinking issues (solved)
------------------------

It's almost working except for blinking issues. The reason is that it has the following execution order:

```
on_bytes -> redraw -> nvim_buf_set_lines (through vim.schedule from on_bytes) -> redraw (through nvim__buf_redraw_range)
```

Possible solution:
  * use string instead of separate buffer. **This approach is used**
  * partially syntax highlight in initial redraw using previous syntax information (still blinking)

Usage
-----

Note: **Should work but not stable at all.**

* Open a `*.t` ntangle file
* Override treesitter decoration provider `lua require"ntangle-ts".override()`
* Attach to current buffer `lua require"ntangle-ts".attach()`
* After modifying the buffer, it should syntax highlight using `ntangle-ts`

Improvements
------------

* [ ] incremental tangling
