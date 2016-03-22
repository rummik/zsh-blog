" Vim syntax file
" Language:	zblog post syntax
" Maintainer:	rummik <k@9k1.us>
" Last Chnage:	Tue Jun 22 16:09:27 CDT 2010
" Based On:	mail.vim

" Quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

runtime! syntax/html.vim

syn cluster 	zblogHeaderFields		contains=zblogHeaderKey,@zblogLinks
syn cluster 	zblogLinks			contains=zblogURL,zblogEmail


syn region	zblogHeader	keepend		contains=@zblogHeaderFields,@zblogQuoteExps,@NoSpell start="^\v(title|tags|id|author|date|flags):" end="^\v-{4,}" fold
syn match	zblogHeaderKey	contained	contains=@NoSpell "^\v(title|tags|id|author|date|flags):"


syn match 	zblogURL 			contains=@NoSpell `\v<(((https?|ftp)://|(mailto|file):)[^' 	<>"]+|[a-z0-9_-]+\.[a-z0-9._-]+\.[^' 	<>"]+)[a-z0-9/]`
syn match 	zblogEmail 			contains=@NoSpell "\v[_=a-z\./+0-9-]+\@[a-z0-9._-]+\a{2}"


syn match	zblogExcerpt			contains=@NoSpell "^\v\~{4,}"


" Need to sync on the header. Assume we can do that within 100 lines
if exists("zblog_minlines")
    exec "syn sync minlines=" . zblog_minlines
else
    syn sync minlines=100
endif


hi def link zblogHeader		Statement
hi def link zblogHeaderKey	Type
hi def link zblogHeaderEmail	zblogEmail
hi def link zblogExcerpt	Statement
hi def link zblogEmail		Special
hi def link zblogURL		String

let b:current_syntax = "zblog"
