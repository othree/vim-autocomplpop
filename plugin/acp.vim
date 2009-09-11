"=============================================================================
" Copyright (c) 2007-2009 Takeshi NISHIDA
"
" GetLatestVimScripts: 1879 1 :AutoInstall: AutoComplPop
"=============================================================================
" LOAD GUARD {{{1

if exists('g:loaded_acp') || v:version < 702
  finish
endif
let g:loaded_acp = 1

" }}}1
"=============================================================================
" FUNCTION: {{{1

"
function s:initialize()
  "...........................................................................
  function s:getSidPrefix()
    return matchstr(expand('<sfile>'), '<SNR>\d\+_')
  endfunction
  let s:PREFIX_SID = s:getSidPrefix()
  delfunction s:getSidPrefix
  "...........................................................................
  call s:defineOption('g:acp_enableAtStartup', 1)
  call s:defineOption('g:acp_mappingDriven', 0)
  call s:defineOption('g:acp_ignorecaseOption', 1)
  call s:defineOption('g:acp_completeOption', '.,w,b,k')
  call s:defineOption('g:acp_completeoptPreview', 0)
  call s:defineOption('g:acp_behaviorKeywordCommand', "\<C-p>")
  call s:defineOption('g:acp_behaviorKeywordLength', 2)
  call s:defineOption('g:acp_behaviorFileLength', 0)
  call s:defineOption('g:acp_behaviorRubyOmniMethodLength', 0)
  call s:defineOption('g:acp_behaviorRubyOmniSymbolLength', 1)
  call s:defineOption('g:acp_behaviorPythonOmniLength', 0)
  call s:defineOption('g:acp_behaviorHtmlOmniLength', 0)
  call s:defineOption('g:acp_behaviorCssOmniPropertyLength', 1)
  call s:defineOption('g:acp_behaviorCssOmniValueLength', 0)
  call s:defineOption('g:acp_behavior', {})
  "...........................................................................
  call extend(g:acp_behavior, s:makeDefaultBehavior(), 'keep')
  "...........................................................................
  command! -bar -narg=0 AcpEnable  call s:enable()
  command! -bar -narg=0 AcpDisable call s:disable()
  command! -bar -narg=0 AcpLock    call s:popupFeeder.lock()
  command! -bar -narg=0 AcpUnlock  call s:popupFeeder.unlock()
  "...........................................................................
  inoremap <silent> <expr> <Plug>AcpOnPopupPost <SID>getPopupFeeder().onPopupPost()
  "...........................................................................
  if g:acp_enableAtStartup
    AcpEnable
  endif
  "...........................................................................
endfunction

"
function s:defineOption(name, default)
  if !exists(a:name)
    let {a:name} = a:default
  endif
endfunction

"
function s:makeDefaultBehavior()
  let behavs = {
        \   '*'      : [],
        \   'ruby'   : [],
        \   'python' : [],
        \   'html'   : [],
        \   'xhtml'  : [],
        \   'css'    : [],
        \ }
  "...........................................................................
  " TODO: make option for this 'command' 
  if g:acp_behaviorKeywordLength >= 0
    for key in keys(behavs)
      call add(behavs[key], {
            \   'command'  : g:acp_behaviorKeywordCommand,
            \   'pattern'  : printf('\k\{%d,}$', g:acp_behaviorKeywordLength),
            \   'repeat'   : 0,
            \ })
    endfor
  endif
  "...........................................................................
  if g:acp_behaviorFileLength >= 0
    for key in keys(behavs)
      call add(behavs[key], {
            \   'command'  : "\<C-x>\<C-f>",
            \   'pattern'  : printf('\f[%s]\f\{%d,}$', (has('win32') || has('win64') ? '/\\' : '/'),
            \                       g:acp_behaviorFileLength),
            \   'excluded' : '[*/\\][/\\]\f*$\|[^[:print:]]\f*$',
            \   'repeat'   : 1,
            \ })
    endfor
  endif
  "...........................................................................
  if has('ruby') && g:acp_behaviorRubyOmniMethodLength >= 0
    call add(behavs.ruby, {
          \   'command'  : "\<C-x>\<C-o>",
          \   'pattern'  : printf('[^. \t]\(\.\|::\)\k\{%d,}$', g:acp_behaviorRubyOmniMethodLength),
          \   'repeat'   : 0,
          \ })
  endif
  "...........................................................................
  if has('ruby') && g:acp_behaviorRubyOmniSymbolLength >= 0
    call add(behavs.ruby, {
          \   'command'  : "\<C-x>\<C-o>",
          \   'pattern'  : printf('\(^\|[^:]\):\k\{%d,}$', g:acp_behaviorRubyOmniSymbolLength),
          \   'repeat'   : 0,
          \ })
  endif
  "...........................................................................
  if has('python') && g:acp_behaviorPythonOmniLength >= 0
    call add(behavs.python, {
          \   'command'  : "\<C-x>\<C-o>",
          \   'pattern'  : printf('\k\.\k\{%d,}$', g:acp_behaviorPythonOmniLength),
          \   'repeat'   : 0,
          \ })
  endif
  "...........................................................................
  if g:acp_behaviorHtmlOmniLength >= 0
    let behav_html = {
          \   'command'  : "\<C-x>\<C-o>",
          \   'pattern'  : printf('\(<\|<\/\|<[^>]\+ \|<[^>]\+=\"\)\k\{%d,}$', g:acp_behaviorHtmlOmniLength),
          \   'repeat'   : 1,
          \ }
    call add(behavs.html , behav_html)
    call add(behavs.xhtml, behav_html)
  endif
  "...........................................................................
  if g:acp_behaviorCssOmniPropertyLength >= 0
    call add(behavs.css, {
          \   'command'  : "\<C-x>\<C-o>",
          \   'pattern'  : printf('\(^\s\|[;{]\)\s*\k\{%d,}$', g:acp_behaviorCssOmniPropertyLength),
          \   'repeat'   : 0,
          \ })
  endif
  "...........................................................................
  if g:acp_behaviorCssOmniValueLength >= 0
    call add(behavs.css, {
          \   'command'  : "\<C-x>\<C-o>",
          \   'pattern'  : printf('[:@!]\s*\k\{%d,}$', g:acp_behaviorCssOmniValueLength),
          \   'repeat'   : 0,
          \ })
  endif
  "...........................................................................
  return behavs
endfunction

"
function s:getPopupFeeder()
  return s:popupFeeder
endfunction

"
function s:enable()
  call s:disable()

  augroup AcpGlobalAutoCommand
    autocmd!
    autocmd InsertEnter * let s:popupFeeder.last_pos = [] | unlet s:popupFeeder.last_pos
    autocmd InsertLeave * call s:popupFeeder.finish()
  augroup END

  if g:acp_mappingDriven
    call s:feedMapping.map()
  else
    autocmd AcpGlobalAutoCommand CursorMovedI * call s:popupFeeder.feed()
  endif

  nnoremap <silent> i i<C-r>=<SID>getPopupFeeder().feed()<CR>
  nnoremap <silent> a a<C-r>=<SID>getPopupFeeder().feed()<CR>
  nnoremap <silent> R R<C-r>=<SID>getPopupFeeder().feed()<CR>
endfunction

"
function s:disable()
  call s:feedMapping.unmap()
  augroup AcpGlobalAutoCommand
    autocmd!
  augroup END
  nnoremap i <Nop> | nunmap i
  nnoremap a <Nop> | nunmap a
  nnoremap R <Nop> | nunmap R
endfunction

" }}}1
"=============================================================================
" OBJECT: PopupFeeder: {{{1

let s:popupFeeder = { 'behavs' : [], 'lock_count' : 0 }

"
function s:popupFeeder.feed()
  " NOTE: CursorMovedI is not triggered while the popup menu is visible. And
  "       it will be triggered when popup menu is disappeared.

  if self.lock_count > 0 || pumvisible() || &paste
    return ''
  endif

  let cursor_moved = self.checkCursorAndUpdate()
  if exists('self.behavs[0]') && self.behavs[0].repeat
    let self.behavs = (self.behavs[0].repeat ? [ self.behavs[0] ] : [])
  elseif cursor_moved 
    let self.behavs = copy(exists('g:acp_behavior[&filetype]') ? g:acp_behavior[&filetype]
          \                                                    : g:acp_behavior['*'])
  else
    let self.behavs = []
  endif

  let cur_text = strpart(getline('.'), 0, col('.') - 1)
  call filter(self.behavs, 'cur_text =~ v:val.pattern && (!exists(''v:val.excluded'') || cur_text !~ v:val.excluded)')

  if empty(self.behavs)
    call self.finish()
    return ''
  endif

  " In case of dividing words by symbols while a popup menu is visible,
  " popup is not available unless input <C-e> or try popup once.
  " (E.g. "for(int", "ab==cd") So duplicates first completion.
  call insert(self.behavs, self.behavs[0])

  call s:optionManager.set('completeopt', 'menuone' . (g:acp_completeoptPreview ? ',preview' : ''))
  call s:optionManager.set('complete', g:acp_completeOption)
  call s:optionManager.set('ignorecase', g:acp_ignorecaseOption)
  call s:optionManager.set('lazyredraw', !g:acp_mappingDriven)
  call s:popupFeeder.setCompletefunc()
  " NOTE: With CursorMovedI driven, Set 'lazyredraw' to avoid flickering.
  "       With Mapping driven, set 'nolazyredraw' to make a popup menu visible.

  " use <Plug> for silence instead of <C-r>=
  call feedkeys(self.behavs[0].command, 'n') 
  call feedkeys("\<Plug>AcpOnPopupPost", 'm')
  return '' " for <C-r>=
endfunction

"
function s:popupFeeder.finish()
  let self.behavs = []
  call s:optionManager.restoreAll()
endfunction

"
function s:popupFeeder.lock()
  let self.lock_count += 1
endfunction

"
function s:popupFeeder.unlock()
  let self.lock_count -= 1
  if self.lock_count < 0
    let self.lock_count = 0
    throw "autocomplpop.vim: not locked"
  endif
endfunction

"
function s:popupFeeder.setCompletefunc()
  if exists('self.behavs[0].completefunc')
    call s:optionManager.set('completefunc', self.behavs[0].completefunc)
  endif
endfunction

"
function s:popupFeeder.checkCursorAndUpdate()
  let prev_pos = (exists('self.last_pos') ? self.last_pos : [-1, -1, -1, -1])
  let self.last_pos = getpos('.')

  if has('multi_byte_ime')
    return (prev_pos[1] != self.last_pos[1] || prev_pos[2] + 1 == self.last_pos[2] ||
          \ prev_pos[2] > self.last_pos[2])
  else
    return (prev_pos != self.last_pos)
  endif
endfunction

"
function s:popupFeeder.onPopupPost()
  if pumvisible()
    " a command to restore to original text and select the first match
    return (self.behavs[0].command =~# "\<C-p>" ? "\<C-n>\<Up>" : "\<C-p>\<Down>")
  elseif exists('self.behavs[1]')
    call remove(self.behavs, 0)
    call s:popupFeeder.setCompletefunc()
    return printf("\<C-e>%s\<C-r>=%sgetPopupFeeder().onPopupPost()\<CR>",
          \       self.behavs[0].command, s:PREFIX_SID)
  else
    call self.finish()
    return "\<C-e>"
  endif
endfunction

" }}}1
"=============================================================================
" OBJECT: OptionManager: sets or restores temporary options {{{1

let s:optionManager = { 'originals' : {} }

"
function s:optionManager.set(name, value)
  call extend(self.originals, { a:name : eval('&' . a:name) }, 'keep')
  execute printf('let &%s = a:value', a:name)
endfunction

"
function s:optionManager.restoreAll()
  for [name, value] in items(self.originals)
    execute printf('let &%s = value', name)
  endfor
  let self.originals = {}
endfunction

" }}}1
"=============================================================================
" OBJECT: FeedMapping: manages global mappings {{{1

let s:feedMapping = { 'keys' :  [] }

"
function s:feedMapping.map()
  call self.unmap()

  let self.keys = [
        \ 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm',
        \ 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
        \ 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
        \ 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
        \ '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
        \ '-', '_', '~', '^', '.', ',', ':', '!', '#', '=', '%', '$', '@', '<', '>', '/', '\',
        \ '<Space>', '<C-h>', '<BS>', ]

  for key in self.keys
    execute printf('inoremap <silent> %s %s<C-r>=<SID>getPopupFeeder().feed()<CR>',
          \        key, key)
  endfor
endfunction

"
function s:feedMapping.unmap()
  for key in self.keys
    execute 'iunmap ' . key
  endfor

  let self.keys = []
endfunction

" }}}1
"=============================================================================
" INITIALIZATION {{{1

call s:initialize()

" }}}1
"=============================================================================
" vim: set fdm=marker:
