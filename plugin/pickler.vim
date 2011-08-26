" pickler.vim - Pivotal Tracker omnicomplete
" Maintainer:   Tim Pope <http://tpo.pe/>

if exists("g:loaded_pickler") || v:version < 700 || &cp
  finish
endif
let g:loaded_pickler = 1

function! pickler#omnifunc(findstart,base)
  if a:findstart
    let existing = matchstr(getline('.')[0:col('.')-1],'#\d*$')
    return col('.')-1-strlen(existing)
  endif
  let stories = split(system('pickler search --state=started'),"\n")
  return map(stories,'{"word": "#".matchstr(v:val,"^\\d\\+"), "menu": matchstr(v:val,"^\\d\\+\\s*.. . \\zs.*")}')
endfunction

augroup pickler
  autocmd!
  autocmd BufRead *.git/COMMIT_EDITMSG
        \ if filereadable(substitute(expand('<afile>'),'\.git.\w\+$','features/tracker.yml','')) |
        \   setlocal omnifunc=pickler#omnifunc |
        \ endif
augroup END

" vim:set ft=vim sw=2 sts=2:
