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
* [x] Modify section line -> reference line
* [x] Modify text line -> section line
* [x] Modify reference line -> section line
* [x] Get inserted text
* [ ] Add/Remove root sections
* [ ] Handle tabs
* [ ] Mitigate circular references
* [ ] row, col for modifications
* [ ] Cache sections (unmodified not recomputed)
...

## Notes

### #1

Let the following code
```
@hello=
@a
@b
@b+=
bb
@a+=
aaaaa
```

With character granularity, it produces the following
output:

```
aaaaabb
```

The last line doesn't contain a newline character.
But the following is expected:

```
aaaaa
bb
```

### Solution to #1

Append a virtual character `\n` at the end.
