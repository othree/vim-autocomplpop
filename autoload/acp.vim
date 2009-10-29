"=============================================================================
" Copyright (c) 2007-2009 Takeshi NISHIDA
"
"=============================================================================
" LOAD GUARD {{{1

if exists('g:loaded_autoload_acp') || v:version < 702
  finish
endif
let g:loaded_autoload_acp = 1

" }}}1
"=============================================================================
" GLOBAL FUNCTIONS: {{{1

"
function acp#enable()
  call acp#disable()

  augroup AcpGlobalAutoCommand
    autocmd!
    autocmd InsertEnter * unlet! s:posLast s:lastUncompletableWord
    autocmd InsertLeave * call s:finishPopup(1)
  augroup END

  if g:acp_mappingDriven
    call s:mapForMappingDriven()
  else
    autocmd AcpGlobalAutoCommand CursorMovedI * call s:feedPopup()
  endif

  nnoremap <silent> i i<C-r>=<SID>feedPopup()<CR>
  nnoremap <silent> a a<C-r>=<SID>feedPopup()<CR>
  nnoremap <silent> R R<C-r>=<SID>feedPopup()<CR>
endfunction

"
function acp#disable()
  call s:unmapForMappingDriven()
  augroup AcpGlobalAutoCommand
    autocmd!
  augroup END
  nnoremap i <Nop> | nunmap i
  nnoremap a <Nop> | nunmap a
  nnoremap R <Nop> | nunmap R
endfunction

"
function acp#lock()
  let s:lockCount += 1
endfunction

"
function acp#unlock()
  let s:lockCount -= 1
  if s:lockCount < 0
    let s:lockCount = 0
    throw "AutoComplPop: not locked"
  endif
endfunction

"
function acp#requireForSnipmate(context)
  if g:acp_behaviorSnipmateLength < 0
    return 0
  endif
  let matches = matchlist(a:context, '\(^\|\s\|\<\)\(\u\{' .
        \                            g:acp_behaviorSnipmateLength . ',}\)$')
  return !empty(matches) && !empty(s:getMatchingSnipItems(matches[2]))
endfunction

"
function acp#requireForKeyword(context)
  return g:acp_behaviorKeywordLength >= 0 &&
        \ a:context =~ '\k\{' . g:acp_behaviorKeywordLength . ',}$'
endfunction

"
function acp#requireForFile(context)
  if g:acp_behaviorFileLength < 0
    return 0
  endif
  if has('win32') || has('win64')
    let separator = '[/\\]'
  else
    let separator = '\/'
  endif
  if a:context !~ '\f' . separator . '\f\{' . g:acp_behaviorFileLength . ',}$'
    return 0
  endif
  return a:context !~ '[*/\\][/\\]\f*$\|[^[:print:]]\f*$'
endfunction

"
function acp#requireForRubyOmni(context)
  if !has('ruby')
    return 0
  endif
  if g:acp_behaviorRubyOmniMethodLength >= 0 &&
        \ a:context =~ '[^. \t]\(\.\|::\)\k\{' .
        \              g:acp_behaviorRubyOmniMethodLength . ',}$'
    return 1
  endif
  if g:acp_behaviorRubyOmniSymbolLength >= 0 &&
        \ a:context =~ '\(^\|[^:]\):\k\{' .
        \              g:acp_behaviorRubyOmniSymbolLength . ',}$'
    return 1
  endif
  return 0
endfunction

"
function acp#requireForPythonOmni(context)
  return has('python') &&
        \ a:context =~ '\k\.\k\{' . g:acp_behaviorPythonOmniLength . ',}$'
endfunction

"
function acp#requireForXmlOmni(context)
  return a:context =~ '\(<\|<\/\|<[^>]\+ \|<[^>]\+=\"\)\k\{' .
        \             g:acp_behaviorXmlOmniLength . ',}$'
endfunction

"
function acp#requireForCssOmni(context)
  if g:acp_behaviorCssOmniPropertyLength >= 0 &&
        \ a:context =~ '\(^\s\|[;{]\)\s*\k\{' .
        \              g:acp_behaviorCssOmniPropertyLength . ',}$'
    return 1
  endif
  if g:acp_behaviorCssOmniValueLength >= 0 &&
        \ a:context =~ '[:@!]\s*\k\{' .
        \              g:acp_behaviorCssOmniValueLength . ',}$'
    return 1
  endif
  return 0
endfunction

"
function acp#completeSnipmate(findstart, base)
  if a:findstart
    return len(matchstr(s:getCurrentText(), '.*\U'))
  endif
  let lenBase = len(a:base)
  let items = filter(GetSnipsInCurrentScope(),
        \            'strpart(v:key, 0, lenBase) ==? a:base')
  return map(items(items), 's:makeSnipmateItem(v:val[0], v:val[1])')
endfunction

"
function acp#onPopupCloseSnipmate()
  let text = s:getCurrentText()
  let lenText = len(text)
  for trigger in keys(GetSnipsInCurrentScope())
    let lenTrigger = len(trigger)
    if lenText >= lenTrigger && strridx(text, trigger) + lenTrigger == lenText
      call feedkeys("\<C-r>=TriggerSnippet()\<CR>", "n")
      return 0
    endif
  endfor
  return 1
endfunction

"
function acp#onPopupPost()
  if pumvisible()
    inoremap <silent> <expr> <C-h> acp#onBs()
    inoremap <silent> <expr> <BS>  acp#onBs()
    " a command to restore to original text and select the first match
    return (s:behavsCurrent[0].command =~# "\<C-p>" ? "\<C-n>\<Up>"
          \                                         : "\<C-p>\<Down>")
  elseif exists('s:behavsCurrent[1]')
    call remove(s:behavsCurrent, 0)
    call s:setCompletefunc()
    return printf("\<C-e>%s\<C-r>=acp#onPopupPost()\<CR>",
          \       s:behavsCurrent[0].command)
  else
    let s:lastUncompletableWord = s:getCurrentWord()
    call s:finishPopup(0)
    return "\<C-e>"
  endif
endfunction

"
function acp#onBs()
  " using "matchstr" and not "strpart" in order to handle multi-byte
  " characters
  if s:matchesBehavior(matchstr(s:getCurrentText(), '.*\ze.'),
        \              s:behavsCurrent[0])
    return "\<BS>"
  endif
  return "\<C-e>\<BS>"
endfunction

" }}}1
"=============================================================================
" LOCAL FUNCTIONS: {{{1

"
function s:mapForMappingDriven()
  call s:unmapForMappingDriven()
  let s:keysMappingDriven = [
        \ 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm',
        \ 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
        \ 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
        \ 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
        \ '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
        \ '-', '_', '~', '^', '.', ',', ':', '!', '#', '=', '%', '$', '@', '<', '>', '/', '\',
        \ '<Space>', '<C-h>', '<BS>', ]
  for key in s:keysMappingDriven
    execute printf('inoremap <silent> %s %s<C-r>=<SID>feedPopup()<CR>',
          \        key, key)
  endfor
endfunction

"
function s:unmapForMappingDriven()
  if !exists('s:keysMappingDriven')
    return
  endif
  for key in s:keysMappingDriven
    execute 'iunmap ' . key
  endfor
  let s:keysMappingDriven = []
endfunction

"
function s:setTempOption(group, name, value)
  call extend(s:tempOptionSet[a:group], { a:name : eval('&' . a:name) }, 'keep')
  execute printf('let &%s = a:value', a:name)
endfunction

"
function s:restoreTempOptions(group)
  for [name, value] in items(s:tempOptionSet[a:group])
    execute printf('let &%s = value', name)
  endfor
  let s:tempOptionSet[a:group] = {}
endfunction

"
function s:getCurrentWord()
  return matchstr(s:getCurrentText(), '\k*$')
endfunction

"
function s:getCurrentText()
  return strpart(getline('.'), 0, col('.') - 1)
endfunction

"
function s:matchesBehavior(text, behav)
  return call(a:behav.require, [a:text])
endfunction

"
function s:isCursorMovedSinceLastCall()
  if exists('s:posLast')
    let posPrev = s:posLast
  endif
  let s:posLast = getpos('.')
  if !exists('posPrev')
    return 1
  elseif has('multi_byte_ime')
    return (posPrev[1] != s:posLast[1] || posPrev[2] + 1 == s:posLast[2] ||
          \ posPrev[2] > s:posLast[2])
  else
    return (posPrev != s:posLast)
  endif
endfunction

"
function s:feedPopup()
  " NOTE: CursorMovedI is not triggered while the popup menu is visible. And
  "       it will be triggered when popup menu is disappeared.
  if s:lockCount > 0 || pumvisible() || &paste
    return ''
  endif
  if exists('s:behavsCurrent[0].onPopupClose')
    if !call(s:behavsCurrent[0].onPopupClose, [])
      call s:finishPopup(1)
      return ''
    endif
  endif
  let cursorMoved = s:isCursorMovedSinceLastCall()
  if exists('s:behavsCurrent[0].repeat') && s:behavsCurrent[0].repeat
    let s:behavsCurrent = [ s:behavsCurrent[0] ]
  elseif cursorMoved
    let s:behavsCurrent = copy(exists('g:acp_behavior[&filetype]')
          \                    ? g:acp_behavior[&filetype]
          \                    : g:acp_behavior['*'])
  else
    let s:behavsCurrent = []
  endif
  if exists('s:lastUncompletableWord') &&
        \ stridx(s:getCurrentWord(), s:lastUncompletableWord) == 0
    let s:behavsCurrent = []
  else
    unlet! s:lastUncompletableWord
    let text = s:getCurrentText()
    call filter(s:behavsCurrent, 's:matchesBehavior(text, v:val)')
  endif
  if empty(s:behavsCurrent)
    call s:finishPopup(1)
    return ''
  endif
  " In case of dividing words by symbols (e.g. "for(int", "ab==cd") while a
  " popup menu is visible, another popup is not available unless input <C-e>
  " or try popup once. So first completion is duplicated.
  call insert(s:behavsCurrent, s:behavsCurrent[0])
  call s:setTempOption(s:GROUP0, 'spell', 0)
  call s:setTempOption(s:GROUP0, 'completeopt', 'menuone' . (g:acp_completeoptPreview ? ',preview' : ''))
  call s:setTempOption(s:GROUP0, 'complete', g:acp_completeOption)
  call s:setTempOption(s:GROUP0, 'ignorecase', g:acp_ignorecaseOption)
  " NOTE: With CursorMovedI driven, Set 'lazyredraw' to avoid flickering.
  "       With Mapping driven, set 'nolazyredraw' to make a popup menu visible.
  call s:setTempOption(s:GROUP0, 'lazyredraw', !g:acp_mappingDriven)
  " NOTE: 'textwidth' must be restored after <C-e>.
  call s:setTempOption(s:GROUP1, 'textwidth', 0)
  call s:setCompletefunc()
  call feedkeys(s:behavsCurrent[0].command, 'n') " use <Plug> for silence instead of <C-r>=
  call feedkeys("\<Plug>AcpOnPopupPost", 'm')
  return '' " for <C-r>=
endfunction

"
function s:finishPopup(fGroup1)
  inoremap <C-h> <Nop> | iunmap <C-h>
  inoremap <BS>  <Nop> | iunmap <BS>
  let s:behavsCurrent = []
  call s:restoreTempOptions(s:GROUP0)
  if a:fGroup1
    call s:restoreTempOptions(s:GROUP1)
  endif
endfunction

"
function s:setCompletefunc()
  if exists('s:behavsCurrent[0].completefunc')
    call s:setTempOption(0, 'completefunc', s:behavsCurrent[0].completefunc)
  endif
endfunction

"
function s:makeSnipmateItem(key, snip)
  if type(a:snip) == type([])
    let descriptions = map(copy(a:snip), 'v:val[0]')
    let snipFormatted = '[MULTI] ' . join(descriptions, ', ')
  else
    let snipFormatted = substitute(a:snip, '\(\n\|\s\)\+', ' ', 'g')
  endif
  return  {
        \   'word': a:key,
        \   'menu': strpart(snipFormatted, 0, 80),
        \ }
endfunction

"
function s:getMatchingSnipItems(base)
  let key = a:base . "\n"
  if !exists('s:snipItems[key]')
    let s:snipItems[key] = items(GetSnipsInCurrentScope())
    call filter(s:snipItems[key], 'strpart(v:val[0], 0, len(a:base)) ==? a:base')
    call map(s:snipItems[key], 's:makeSnipmateItem(v:val[0], v:val[1])')
  endif
  return s:snipItems[key]
endfunction

" }}}1
"=============================================================================
" INITIALIZATION {{{1

let s:GROUP0 = 0
let s:GROUP1 = 1
let s:lockCount = 0
let s:behavsCurrent = []
let s:tempOptionSet = [{}, {}]
let s:snipItems = {}

inoremap <silent> <expr> <Plug>AcpOnPopupPost acp#onPopupPost()


" }}}1
"=============================================================================
" vim: set fdm=marker:
