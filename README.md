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
