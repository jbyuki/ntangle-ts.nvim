function! ntangle_ts#foldexpr() abort
  let s:line = getline(v:lnum)
  let s:matched = matchstr(s:line, '@[a-zA-Z_-]\+[+-]\?=')
  if s:matched == ""
    return "1"
  else
    return ">1"
  endif
endfunction

function! ntangle_ts#foldtext() abort
  let s:line = getline(v:foldstart)
  let s:section = substitute(s:line, '_', ' ', "g")
  let s:section = substitute(s:section, '@', '', "")
  let s:section = substitute(s:section, '[+-]\?=', '', "")
  return "@ " . s:section
endfunction
