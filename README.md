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

Usage
-----

Status: **unstable**

```vim
lua require"ntangle-ts".override()

augroup ntanglets
	autocmd!
	autocmd BufRead *.t lua require"ntangle-ts".attach()
augroup END
```

Improvements
------------

* [x] incremental tangling
* [x] assemblies
* [x] on_bytes
* [ ] undefined sections
* [ ] multiple roots
