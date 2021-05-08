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

Status: Everything is implemented but there might be still instabilities

It should work out of the box. Open a `*.t` and it should syntax
highlight it properly. Please make sure the corresponding treesitter
parser is installed (see info using `:TSInstallInfo`).


Improvements
------------

* [x] incremental tangling
* [x] assemblies
* [x] on_bytes
* [x] multiple roots
