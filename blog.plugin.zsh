#!/bin/zsh

ZSH_BLOG_VERSION=0.8

autoload -U regexp-replace
zmodload zsh/pcre
zmodload zsh/mathfunc

# find where we're being called from
if [[ -z "$ZSH_BLOG" ]]; then
	ZSH_BLOG=${0:h}

	# fix for sourcing from the current directory
	[[ $ZSH_BLOG == . ]] &&
		ZSH_BLOG=$PWD

	# try to get an absolute path
	[[ "${ZSH_BLOG:0:1}" != "/" && "${ZSH_BLOG:0:1}" != "~" ]] &&
		ZSH_BLOG=$PWD/$ZSH_BLOG
fi


# main blog function
# divvys up commands to functions, as well as handles other important things
function blog {
	emulate -L zsh
	setopt rematchpcre

	local BROOT cmd version help
	local -a plugins
	local -A blog args

	plugins=(links)

	blog=(
		title        'My Blog'
		tagline      'Just another Zsh blog'
		root         '/'
		archives     '/archives'
		posts        5
		recent-posts 10
	)

	## handle option parsing
	zparseopts -E -D -version=version -help=help

	if [[ ! -z $version ]]; then
		print blog version $ZSH_BLOG_VERSION
		return
	fi

	[[ ! -z $help ]] &&
		cmd=help

	### cleanup option parsing
	unset version help


	## set $cmd if it is not set (default to 'help')
	if [[ -z $cmd ]]; then
		cmd=${1:-help}
		[[ $# -gt 0 ]] && shift
	fi


	## divvy up commands
	if ! whence "blog-$cmd" > /dev/null; then
		print "blog: '$cmd' is not a blog command. See 'blog --help'."
	else
		BROOT=$(-blog-root)

		if [[ $cmd != 'help' && $cmd != 'init' && $? -eq 1 ]]; then
			print 'fatal: Not a ZSH blog (or any parent up to /)'
			return 1
		fi

		"blog-$cmd" $@
		return $?
	fi
}

# determine the blog root path
function -blog-root {
	local root=$PWD

	while [[ $root != / && ! -d "$root/.blog" ]]; do
		root=$(dirname $root)
	done

	if [[ $root != / ]]; then
		print $root/.blog
	else
		print $PWD/.blog
		return 1
	fi
}

# completion
function _blog {
	emulate -L zsh

	local curcontext="$curcontext" context state state_descr line
	local -A opt_args

	_arguments \
		'1: :->command' \
		'*: :->argument' \
		--

	case $state in
		command)
			compadd -- ${="$(whence -mw 'blog-*')"//(blog-|: (function|alias|command))};;

		argument)
			BROOT=$(-blog-root)
			[[ $? -eq 1 ]] && return 1
			;;
	esac
}

compdef _blog blog


# actions
# -------
# actions are meant to be called by blog (above)

## display help for various topics
function blog-help {
	local page=${1:-main}

	if [[ ! -f $ZSH_BLOG/help/$page ]]; then
		print "blog: No help for '$1'"
	else
		print -- "$(< $ZSH_BLOG/help/$page)"
	fi
}

## create a blog post
alias blog-add=blog-new
function blog-new {
	local type=${1:-post}
	local source=$ZSH_BLOG/templates/content/$type
	local file=$(-blog-mktemp)

	if [[ -f $source ]]; then
		cp $source $file

		if -blog-edit $file; then
			mv $file $BROOT/posts/$(-blog-getNewPostID)
			print "blog: Adding post ($1)."
			blog-update
		else
			rm $file
		fi
	else
		print "blog: Unknown post type '$type'."
	fi
}

## edit a blog post
function blog-edit {
	if -blog-edit $BROOT/posts/$1; then
		print "blog: Updating post ($1)."
		blog-update
	fi
}

## initialize a new blog
function blog-init {
	if [[ ! -d $BROOT ]]; then
		cp -r $ZSH_BLOG/default $BROOT
		print Initialized emptly blog in $BROOT
	else
		print Politely declining to reinitialize blog in $BROOT
	fi
}

## list blog posts
alias blog-list=blog-ls
function blog-ls {
	local titleWidth=$((int((COLUMNS - 22) / 1.5)))
	local tagWidth=$(((COLUMNS - 22) - $titleWidth))
	local format="%8.8s | %-5.5s | %-${titleWidth}.${titleWidth}s | %-${tagWidth}.${tagWidth}s\n"
	local -A post

	printf $format 'Post ID' 'Flags' 'Title' 'Tags'
	print -- ${(l.$COLUMNS..-.)}

	for postid in $([[ -f $BROOT/posts/$1 ]] && print $1 || ls -v $BROOT/posts 2> /dev/null); do
		-blog-parse-post $postid
		printf $format $postid "$post[flags]" "$post[title]" "$post[tags]"
	done
}

## clean up blog cache
function blog-clean {
	[[ $(ls $BROOT/cache/*/* 2>/dev/null | wc -l) -gt 0 ]] &&
		(rm -rf $BROOT/cache/*/*)
}

## clean blog cache and rebuild blog
alias blog-regenerate=blog-regen
function blog-regen {
	blog-clean && blog-update
}

## generate blog content
function blog-update {
}


# loaders
# -------

function -blog-load-plugins {
	local _i _load load

	for _i in 1..$#plugins; do
		load=''

		[[ -f ${_load::="$ZSH_BLOG/plugins/${plugins[i]}.zsh"} ]] &&
			load=$_load

		[[ -f ${_load::="$BROOT/plugins/${plugins[i]}.zsh"} ]] &&
			load=$_load

		[[ ! -z $load && $BLOG_LOADED[$plugins[i]] != $load ]] &&
			source ${BLOG_LOADED[$plugins[i]]::=$load}
	done
}

function -blog-load-fragments {
	local i
	for i in 1..$#plugins; do
		functions -- + "-blog-fragment-${plugins[i]}" > /dev/null &&
			fragments[$plugins[i]]="$("-blog-fragment-${plugins[i]}")"
	done
}


# database
# --------

function -blog-getNewPostID {
	print $(($(ls -v $BROOT/posts | tail -n 1) + 1))
}

function -blog-getPostsByDate {
}

function -blog-getPostByID {
	local file=$BROOT/posts/$(printf '%d' "$1")

	[[ $(printf '%d' "$1") = 0 || ! -f $file ]] &&
		return 1

	print $file
}


# helpers
# -------

# create a temp file
function -blog-mktemp {
	mktemp -u /tmp/blog-post.XXXXX
}

# templating engine
function -blog-template {
	print -r -- "${(e)"$(<$BROOT/templates/themes/${blog[theme]:-default}/$1)"//\\/\\\\}"
}

# edit a file
function -blog-edit {
	local source=$1
	local temp=$(-blog-mktemp)
	local return=0

	if [[ -f $source ]]; then
		cp $source $temp
		-blog-editor $temp

		if ! diff $source $temp > /dev/null; then
			cp $temp $source
		else
			print blog: Nothing to do.
			return=1
		fi

		rm $temp
	else
		print blog: Nothing to edit.
		return=1
	fi

	return $return
}

# find an editor and run it
function -blog-editor {
	local editors
	editors=(pico nano vim ed emacs)

	if [[ ! -z $EDITOR && -x $(which $EDITOR) ]]; then
		-blog-editor- $EDITOR $1
	else
		print '$EDITOR not set or missing -- trying some defaults.'

		if ! -blog-editor- "$(which $editors > /dev/null | grep -m 1 /)" $1; then
			print 'Could not find an editor.'
			return 1
		fi
	fi
}

# helper to load syntax highlighting for editor
function -blog-editor- {
	case $1 in
		vim) vim -c "source $ZSH_BLOG/syntax/zblog.vim" $2;;
		'') return 1;;
		*) $1 $2;;
	esac
}

# escape some entities that could break links, titles, etc
function -blog-escape {
	local string="$@"

	regexp-replace string '&' '&amp;'
	regexp-replace string '"' '&quot;'
	regexp-replace string "'" '&apos;'
	regexp-replace string '<' '&lt;'
	regexp-replace string '>' '&gt;'

	print $string
}

# get the value of a header from a post
function -blog-getPostHeader {
	local postid=${2#*-} header=$1 file=$2

	if [[ -f $BROOT/cache/parser/$postid ]]; then
		local -A post
		source $BROOT/cache/parser/$postid
		print -- $post[$header]
		return
	fi

	[[ $file[0,1] != '/' ]] &&
		file=$BROOT/posts/$file

	data=${${${"$(cat - $file <<< '')"%%($'\n'|$'\r')----*}##*($'\n'|$'\r')$header: }%%($'\n'|$'\r')*}

	if [[ $header = (tags|flags) ]] &&
		data=($=data)

	print -- $data
}

# return a formatted date string
function -blog-dateFormat {
	date -d "$1" +"$2"
}

# return a url-safe string from a title
# TODO: use ZSH builtins instead of tr/sed
function -blog-getPrettyURL {
	print -- $@ | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9.-]\+/-/g; s/^-\|-$//g'
}

# get generate a permalink for a post
function -blog-getPermalink {
	local file=$BROOT/posts/$1
	local date="$(-blog-getPostHeader date $file)"
	local title="$(-blog-getPostHeader title $file)"
	local url=${blog[root]%/}/archives/

	url+=$(-blog-dateFormat "$date" '%Y/%m/%d')/
	url+=$(-blog-getPrettyURL $title)/

	print -- $url
}

# parse post into something a bit more useful
function -blog-parse-post {
	local headers preview body
	local postid=${1#*-}
	local file=$BROOT/posts/$postid

	if [[ -f $BROOT/cache/parser/$postid ]]; then
		eval $(<$BROOT/cache/parser/$postid)
		return
	fi

	body=$(<$BROOT/posts/$postid)
	headers=$body

	regexp-replace headers '\n-{4,}\n(\n|.)*' ''

	regexp-replace body '(\n|.)*\n-{4,}\n' ''
	regexp-replace body '\n' '<br>'$'\n'
	regexp-replace body '<br>\n~{4,}(<br>|\s)*$' ''

	preview=$body
	regexp-replace preview '\n~{4,}(<br>(\n|.)*|$)' ''

	regexp-replace body '<br>\n~{4,}(<br>|$)' '<br><br>'

	post=(
		'id'		$postid
		'title'		"$(-blog-getPostHeader title $file)"
		'tags'		"$(-blog-getPostHeader tags $file)"
		'date'		"$(-blog-getPostHeader date $file)"
		'author'	"$(-blog-getPostHeader author $file)"
		'preview'	"$preview"
		'body'		"$body"
		'permalink'	"$(-blog-getPermalink $postid)"
		'flags'		"$(-blog-getPostHeader flags $file)"
	)


	# set post_preview to post_body if the preview is empty
	# TODO: create a short version if the preview does not exist
	post[preview]=${post[preview]:-$post[body]}

	(print 'post=('
	for key in ${(k)post}; do
		print -r -- ${(qq)key} ${(qq)post[$key]}
	done
	print ')') > $BROOT/cache/parser/$postid
}
