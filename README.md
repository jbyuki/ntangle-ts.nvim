## ntangle-ts-next

Second iteration on ntangle-ts.nvim.

The reason I don't develop on the main branch
ntangle-ts.nvim is that I need ntangle-ts.nvim in
order to develop it. That's why I'm creating
a new fresh repository.

The idea of the second iteration is to have
a character by character internal state
representation instead of line by line.
This will avoid any headaches to translate
byte range transformation to line transformation.

## Steps

* [x] Modify text line
* [x] Modify reference line
* [x] Modify reference line -> text line
* [x] Modify text line -> reference line
* [x] Modify section line
* [x] Modify section line -> text line
* [ ] Modify section line -> reference line
* [ ] Modify text line -> section line
* [ ] Modify reference line -> section line
* [ ] Mitigate circular references
...
