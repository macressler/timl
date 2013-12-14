" Maintainer: Tim Pope <http://tpo.pe>

if exists("g:autoloaded_timl_lang")
  finish
endif
let g:autoloaded_timl_lang = 1

function! s:function(name) abort
  return function(substitute(a:name,'^s:',matchstr(expand('<sfile>'), '.*\zs<SNR>\d\+_'),''))
endfunction

function! s:identity(x)
  return a:x
endfunction

function! s:nil(...)
  return g:timl#nil
endfunction

function! s:empty_list(...)
  return g:timl#empty_list
endfunction

function! s:zero(...)
  return 0
endfunction

function! s:implement(type, ...)
  let type = timl#keyword#intern(a:type)
  for i in range(0, a:0-1, 2)
    call timl#type#define_method('timl.core', a:000[i], type, s:function(a:000[i+1]))
  endfor
endfunction

let s:ns = timl#namespace#find('timl.core')
function! s:define_apply(name, fn)
  let g:timl#core#{timl#munge(a:name)} = timl#bless('timl.lang/Function', {
        \ 'name': timl#symbol#intern(a:name),
        \ 'ns': s:ns,
        \ 'apply': s:function(a:fn)})
endfunction

function! s:apply(_) abort
  return call(self.call, a:_, self)
endfunction

function! s:define_call(name, fn)
  let g:timl#core#{timl#munge(a:name)} = timl#bless('timl.lang/Function', {
        \ 'name': timl#symbol#intern(a:name),
        \ 'ns': s:ns,
        \ 'apply': s:function('s:apply'),
        \ 'call': s:function(a:fn)})
endfunction

function! s:define_apply(name, fn)
  let g:timl#core#{timl#munge(a:name)} = timl#bless('timl.lang/Function', {
        \ 'name': timl#symbol#intern(a:name),
        \ 'ns': s:ns,
        \ 'apply': s:function(a:fn)})
endfunction

" Section: Number

call s:define_apply('+', 'timl#number#sum')
call s:define_apply('*', 'timl#number#product')
call s:define_apply('-', 'timl#number#minus')
call s:define_apply('/', 'timl#number#solidus')
call s:define_apply('>', 'timl#number#gt')
call s:define_apply('<', 'timl#number#lt')
call s:define_apply('>=', 'timl#number#gteq')
call s:define_apply('<=', 'timl#number#lteq')
call s:define_apply('==', 'timl#number#equiv')
call s:define_apply('max', 'max')
call s:define_apply('min', 'min')

" Section: String

" Characters, not bytes
function! s:string_lookup(this, idx, default) abort
  if type(a:idx) == type(0)
    let ch = matchstr(a:this, repeat('.', a:idx).'\zs.')
    return empty(ch) ? (a:0 ? a:1 : g:timl#nil) : ch
  endif
  return a:default
endfunction

function! s:string_count(this) abort
  return exists('*strchars') ? strchars(a:this) : len(substitute(a:this, '.', '.', 'g'))
endfunction

call s:implement('vim/String',
      \ 'lookup', 's:string_lookup',
      \ 'count', 's:string_count')

" Section: Nil

function! s:nil_lookup(this, key, default)
  return a:default
endfunction

function! s:nil_cons(this, ...)
  return call('timl#cons#conj', [g:timl#empty_list] + a:000)
endfunction

function! s:nil_assoc(this, ...)
  return timl#map#create(a:000)
endfunction

call s:implement('timl.lang/Nil',
      \ 'seq', 's:nil',
      \ 'first', 's:nil',
      \ 'more', 's:empty_list',
      \ 'conj', 's:nil_cons',
      \ 'assoc', 's:nil_assoc',
      \ 'count', 's:zero',
      \ 'lookup', 's:nil_lookup')

" Section: Boolean

if !exists('g:timl#false')
  let g:timl#false = timl#bless('timl.lang/Boolean', {'value': 0})
  let g:timl#true = timl#bless('timl.lang/Boolean', {'value': 1})
  lockvar 1 g:timl#false g:timl#true
endif

" Section: Symbol/Keyword

function! s:this_get(this, coll, ...) abort
  if a:0
    return timl#get(a:coll, a:this, a:1)
  else
    return timl#get(a:coll, a:this)
  endif
endfunction

call s:implement('timl.lang/Symbol',
      \ '_invoke', 's:this_get')

call s:implement('timl.lang/Keyword',
      \ '_invoke', 's:this_get')

" Section: Function

function! s:function_invoke(this, ...) abort
  return a:this.apply(a:000)
endfunction

call s:implement('timl.lang/Function',
      \ '_invoke', 's:function_invoke')

call s:implement('timl.lang/MultiFn',
      \ '_invoke', 'timl#type#dispatch')

call s:implement('vim/Funcref', '_invoke', 'call')

" Section: Array (Vim List)

call s:implement('vim/List',
      \ 'seq', 'timl#array#seq',
      \ 'first', 'timl#array#first',
      \ 'more', 'timl#array#rest',
      \ 'lookup', 'timl#array#lookup',
      \ 'nth', 'timl#array#nth',
      \ 'count', 'len',
      \ 'conj', 'timl#array#cons',
      \ 'empty', 'timl#array#empty',
      \ '_invoke', 'timl#array#lookup')

call s:implement('vim/List',
      \ 'transient', 'timl#array#transient',
      \ 'conj!', 'timl#array#conjb',
      \ 'persistent!', 'timl#array#persistentb')

" Section: Cons

call s:implement('timl.lang/Cons',
      \ 'seq', 's:identity',
      \ 'first', 'timl#cons#first',
      \ 'more', 'timl#cons#more',
      \ 'conj', 'timl#cons#conj',
      \ 'empty', 's:empty_list')

" Section: Empty list

if !exists('g:timl#empty_list')
  let g:timl#empty_list = timl#bless('timl.lang/EmptyList', {'count': 0})
  lockvar 1 g:timl#empty_list
endif

call s:implement('timl.lang/EmptyList',
      \ 'seq', 's:nil',
      \ 'first', 's:nil',
      \ 'more', 's:identity',
      \ 'count', 's:zero',
      \ 'conj', 'timl#cons#conj',
      \ 'empty', 's:identity')

" Section: Array Seq

call s:implement('timl.lang/ArraySeq',
      \ 'seq', 's:identity',
      \ 'first', 'timl#array_seq#first',
      \ 'more', 'timl#array_seq#more',
      \ 'count', 'timl#array_seq#count',
      \ 'conj', 'timl#cons#conj',
      \ 'empty', 's:empty_list')

" Section: Lazy Seq

call s:implement('timl.lang/LazySeq',
      \ 'seq', 'timl#lazy_seq#seq',
      \ 'realized?', 'timl#lazy_seq#realized',
      \ 'count', 'timl#lazy_seq#count',
      \ 'conj', 'timl#cons#conj',
      \ 'empty', 's:empty_list')

" Section: Dictionary

call s:implement('vim/Dictionary',
      \ 'seq', 'timl#dictionary#seq',
      \ 'lookup', 'timl#dictionary#lookup',
      \ 'empty', 'timl#dictionary#empty',
      \ 'conj', 'timl#dictionary#conj',
      \ 'assoc', 'timl#dictionary#assoc',
      \ 'dissoc', 'timl#dictionary#dissoc',
      \ 'transient', 'timl#dictionary#transient',
      \ 'invoke', 'timl#dictionary#lookup')

call s:implement('vim/Dictionary',
      \ 'conj!', 'timl#dictionary#conjb',
      \ 'assoc!', 'timl#dictionary#assocb',
      \ 'dissoc!', 'timl#dictionary#dissocb',
      \ 'persistent!', 'timl#dictionary#persistentb')

" Section: Hash Map

call s:implement('timl.lang/HashMap',
      \ 'seq', 'timl#map#seq',
      \ 'lookup', 'timl#map#lookup',
      \ 'empty', 'timl#map#empty',
      \ 'conj', 'timl#map#conj',
      \ 'assoc', 'timl#map#assoc',
      \ 'dissoc', 'timl#map#dissoc',
      \ 'transient', 'timl#map#transient',
      \ 'invoke', 'timl#map#lookup')

call s:implement('timl.lang/HashMap',
      \ 'conj!', 'timl#map#conjb',
      \ 'assoc!', 'timl#map#assocb',
      \ 'dissoc!', 'timl#map#dissocb',
      \ 'persistent!', 'timl#map#persistentb')

" Section: Hash Set

call s:implement('timl.lang/HashSet',
      \ 'seq', 'timl#set#seq',
      \ 'lookup', 'timl#set#lookup',
      \ 'empty', 'timl#set#empty',
      \ 'conj', 'timl#set#conj',
      \ 'disj', 'timl#set#disj',
      \ 'transient', 'timl#set#transient',
      \ '_invoke', 'timl#set#lookup')

call s:implement('timl.lang/HashSet',
      \ 'conj!', 'timl#set#conjb',
      \ 'disj!', 'timl#set#disjb',
      \ 'persistent!', 'timl#set#persistentb')

" Section: I/O

call s:define_apply('echo', 'timl#io#echo')
call s:define_apply('echon', 'timl#io#echon')
call s:define_apply('echomsg', 'timl#io#echomsg')
call s:define_apply('print', 'timl#io#echon')
call s:define_apply('println', 'timl#io#println')
call s:define_call('newline', 'timl#io#newline')
call s:define_call('printf', 'timl#io#printf')
call s:define_apply('pr', 'timl#io#pr')
call s:define_apply('prn', 'timl#io#prn')
call s:define_call('spit', 'timl#io#spit')
call s:define_call('slurp', 'timl#io#slurp')
call s:define_call('read-string', 'timl#reader#read_string')

" Section: Defaults

call timl#type#define_method('timl.core', 'empty', g:timl#nil, s:function('s:nil'))

function! s:default_first(x)
  return timl#type#dispatch(g:timl#core#first, timl#type#dispatch(g:timl#core#seq, a:x))
endfunction
call timl#type#define_method('timl.core', 'first', g:timl#nil, s:function('s:default_first'))

function! s:default_count(x)
  return 1 + timl#type#dispatch(g:timl#core#count, timl#type#dispatch(g:timl#core#more, a:x))
endfunction
call timl#type#define_method('timl.core', 'count', g:timl#nil, s:function('s:default_count'))

" vim:set et sw=2:
