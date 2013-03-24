#!/bin/zsh
function _zb_edit {
	local editor editors edited
	editors=(pico nano vim ed)

	if [[ -z $EDITOR || ! -x $(which $EDITOR) ]]; then
		print '$EDITOR not set or missing -- trying some defaults.'

		for editor in $editors; do
			[[ -x $(which $editor) ]] && _zb_synedit $editor $1 && edited=1
		done

		[[ -z $edited ]] && print 'Could not find an editor.' && return 1
	else
		_zb_synedit $EDITOR $1
	fi
}

function _zb_synedit {
	[[ $1 = vim ]] && vim -c 'source ~/.zblog/syntax/zblog.vim' $2 && return 0
	$1 $2
}

function _zb_escape {
	sed "	s/&/\&amp;/g;
		s/\"/\&quot;/g;
		s/'/\&apos;/g;
		s/</\&lt;/g;
		s/>/\&gt;/g;"
}

function _zb_template {
	print -r -- "${(e)"$(<~/.zblog/templates/themes/default/$1)"//\\/\\\\}"
}

function _zb_help {
	local help
	help=${1:-main}
	[[ ! -f ~/.zblog/help/$help ]] && print "blog: No help for '$1'" || cat ~/.zblog/help/$help
}

function _zb_path {
	_zb_path=$1
}

function _zb_link {
	_zb_link=$1
	local slash=0 i=0 link

	while [[ $((i++)) -lt ${#_zb_path} ]]; do
		if [[ $_zb_link[0,$i] = $_zb_path[0,$i] && $_zb_link[$i] = / ]]; then
			slash=$i
			link=$_zb_path[$((i+1)),$((${#_zb_path}-1))]
			regexp-replace link '[^/]+' '..'
			link=${link:-.}$_zb_link[$i,${#_zb_link}]
		fi
	done

	print $link
}

function _zb_permalink {
	local post
	post=${1#*-}
	[[ ! -f ~/.zblog/content/posts/$post ]] && return 0
	print -- $blog[root]/archives/$(date -d "$(_zb_field date $post)" +'%Y/%m/%d')/$(print $(_zb_field title $post) | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9.-]\+/-/ig; s/^-\|-$//g')/\
		| sed 's/\/\+/\//g;'
}

function _zb_parse_post {
	local postid headers preview body
	postid=${1#*-}
	file=~/.zblog/content/posts/$postid

	if [[ -f ~/.zblog/content/cache/parser/$postid ]]; then
		eval $(<~/.zblog/content/cache/parser/$postid)
		return
	fi

	body=$(<~/.zblog/content/posts/$postid)
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
		'title'		"$(_zb_field title $file)"
		'tags'		"$(_zb_field tags $file)"
		'date'		"$(_zb_field date $file)"
		'author'	"$(_zb_field author $file)"
		'preview'	"$preview"
		'body'		"$body"
		'permalink'	"$(_zb_permalink $postid)"
		'flags'		"$(_zb_field flags $file)"
	)


	# set post_preview to post_body if the preview is empty
	# TODO: create a short version if the preview does not exist
	post[preview]=${post[preview]:-$post[body]}

	(print 'post=('
	for key in ${(k)post}; do
		print -r -- ${(qq)key} ${(qq)post[$key]}
	done
	print ')') > ~/.zblog/content/cache/parser/$postid
}

# returns 1 if flag not found, 0 if found
function _zb_flag {
	flag=$1
	flags=$2

	if [[ -z $flags || ${${(s/, /)flags}[(r)$1]} == $1 ]]; then
		return 1
	fi
}

function _zb_field {
	local file p postid post
	p=~/.zblog/content/posts/
	file=$2
	postid=${2#*-}

	[[ $file[0,1] = '/' ]] && p=''

	if [[ ! -z $p && -f ~/.zblog/content/cache/parser/$postid ]]; then
		typeset -A post
		eval $(<~/.zblog/content/cache/parser/$postid)
		print $post[$1]
		return
	fi

	headers=$(<$p/$file)
	regexp-replace headers '[\n\r]-{4,}[\n\r]([\r\n]|.)*' ''
	h=$headers
	regexp-replace headers '^(([\n\r]|.)*[\n\r])?('$1':.*)([\n\r]([\n\r]|.)*)?$' '$match[3]'

	if [[ $headers = $h ]]; then
		headers="$1:"
	fi

	case $1 in
		tags|flags) regexp-replace headers '\s*(,)\s*|\s+' '$match[1] '
		      regexp-replace headers '^'$1':\s*(.*)\s*' '$match[1]';;
		*)    regexp-replace headers '^'$1':\s*(.*)\s*' '$match[1]';;
	esac

	print $headers
}

function _zb_fieldnx {
	[[ -z "$(grep -E "^$2:" /tmp/zblog.tmp.$$ -m 1)" ]] && \
		sed -i 's/^\(-\{4,\}\)/'"$2"': \n\1/;' /tmp/zblog.tmp.$$

	[[ -z "$(grep -E "^$2:$1" /tmp/zblog.tmp.$$ -m 1)" ]] && \
		sed -i "s/^$2:.\+$/$2: $3/;" /tmp/zblog.tmp.$$
}

function _zb_ftp {
	autoload -U zfinit; zfinit
	if zfopen -1 "$blog[ftp_host]" "$blog[ftp_user]" "$blog[ftp_pass]"; then
		if [[ -z $(zfls $blog[ftp_root]) ]] && zfmkdir
		zfcd $blog[ftp_root]
		zfput -r ~/.zblog/content/blog/*
		zfclose
	fi
}

function _zb_sftp {
}

function _zb_archives {
	zmodload zsh/mathfunc
	local i pages p loc
	loc=$1
	i=0
	pages=$((ceil(${#posts}.0 / blog[posts])))
	while [[ $i -lt $pages ]]; do
		p=${${i/#%0/}:+p$i/}

		page[previous]=${p:+/$loc/${${p/#%p1\//}:+p$((i-1))/}}
		page[next]=${${$((pages - i - 1))/#%0./}:+/$loc/p$((i+1))/}

		fragment[posts]=$(xargs cat <<< ${(F)posts[$(((i * $blog[posts]) + 1)),$(((i * $blog[posts]) + $blog[posts]))]})
		page[content]=$(_zb_template content_post.html)

		mkdir -p ~/.zblog/content/blog/$loc/$p
		_zb_template layout.html > ~/.zblog/content/blog/$loc/${p}index.html

		(( i++ ))
	done
}

function blog {
	local version=0.22-Alpha

	local opt blog zblog link links content postid input post posts fragment page tags archives _zb_path _zb_link count fname tagpath weight

	emulate -L zsh
	autoload -U regexp-replace
	setopt rematchpcre
	setopt nonomatch

	typeset -A blog
	typeset -A zblog
	typeset -A content
	typeset -A post
	typeset -A fragment
	typeset -A page
	typeset -U archives
	typeset -A count
	typeset -A links

	zblog=(
		config  ~/.zblog/blog.conf
		content ~/.zblog/content/blog
		version $version
	)

	blog=(
		title        'My Blog'
		tagline      'Just another Zsh blog'
		root         '/'
		archives     '/archives'
		posts        5
		recent-posts 10

		ftp_user     "$USER"
		ftp_pass     ''
		ftp_host     ''
		ftp_root     '~/public_html'

		ftp_cmd      '_zb_ftp'
	)

	links=(
		'Home' '/'
	)

	while getopts hc: opt; do
		case $opt in
			h) $0 help && return;;
			c) [[ -f $OPTARG ]] && zblog[config]=$OPTARG;;
		esac
	done

	[[ -e $zblog[config] ]] && . $zblog[config]

	case $1 in
		add|edit)
			if [[ $1 = add ]]; then
				case $2 in
					article) input=~/.zblog/templates/content/article;;
					draft)   input=~/.zblog/templates/content/draft;;
					*|post)  input=~/.zblog/templates/content/post;;
				esac

				postid=$(($(ls -v ~/.zblog/content/posts | tail -n 1) + 1))
			elif [[ ! $(printf '%d' "$2") = 0 && -f ~/.zblog/content/posts/$(printf '%d' "$2") ]]; then
				postid=$(printf '%d' "$2")
				input=~/.zblog/content/posts/$(printf '%d' "$2")
			else
				print 'Nothing to edit.'
				return 0
			fi

			cp $input /tmp/zblog.tmp.$$

			_zb_edit /tmp/zblog.tmp.$$

			if diff -q $input /tmp/zblog.tmp.$$ > /dev/null; then
				print 'Nothing to do.'
				return 0
			fi

			# add author/date fields if they do not exist, and fill them if blank
			_zb_fieldnx ' *[^ ].*$' author $(whoami)
			_zb_fieldnx '.{8,}$'    date   "$(date -R)"

			if [[ -f ~/.zblog/content/posts/$postid ]]; then
				print "Updating post ($postid)."
			else
				print "Adding post ($postid)."
			fi

			cp /tmp/zblog.tmp.$$ ~/.zblog/content/posts/$postid
			$0 update;;

		ls)
			local format titlew tagw
			titlew=${$(((${COLUMNS} - 22) / 1.5))%%.*}
			tagw=$(((${COLUMNS} - 22) - $titlew))
			format="%8.8s | %-5.5s | %-${titlew}.${titlew}s | %-${tagw}.${tagw}s\n"

			printf $format 'Post ID' 'Flags' 'Title' 'Tags'
			print -- ${(l.((${COLUMNS}))..-.)}

			for postid in $(ls -v ~/.zblog/content/posts); do
				_zb_parse_post $postid
				printf $format $postid "$post[flags]" "$post[title]" "$post[tags]"
			done;;

		rm)
			postid=$(printf '%d' $2)
			[[ ! -f ~/.zblog/content/posts/$postid ]] && print 'Sorry, no post by that ID.' && return 1

			print -n "Really delete post ($postid)? [yes/No] "
			read answer

			if [[ $(tr '[A-Z]' '[a-z]' <<< $answer) = 'yes' ]]; then
				print "Deleting post ($postid)."
				rm ~/.zblog/content/posts/$postid
			else
				print "Not deleting post ($postid)."
			fi

			$0 regen;;

		clean) [[ ! $(ls ~/.zblog/content/cache/posts 2>/dev/null | wc -l) -eq 0 ]] && (rm -rf ~/.zblog/content/cache/*);;

		regen|regenerate)
			$0 clean
			$0 update;;

		update)
			if [[ $(ls ~/.zblog/content/posts/ | wc -l) -eq 0 ]]; then
				print 'Nothing to do...'
				return
			fi

			print 'Updating blog...'

			mkdir -p ~/.zblog/content/cache/{fragments,tags,parser,posts}

			content=()
			# generate fragment and tag cache (improves speed a bit)
			for p in $(diff -q ~/.zblog/content/posts ~/.zblog/content/cache/posts | sed 's/^.\+: //; s/.\+posts\/\([0-9]\+\) .*/\1/;' | sort -n); do
				rm -f ~/.zblog/content/cache/fragments/*-$p
				rm -f ~/.zblog/content/cache/tags/*/*-$p
				rm -f ~/.zblog/content/cache/parser/$p

				if [[ ! -f ~/.zblog/content/posts/$p ]]; then
					rm ~/.zblog/content/cache/posts/$p
				else
					_zb_parse_post $p

					# don't generate post if it's a draft or an article
					_zb_flag draft $post[flags] && continue
					_zb_flag article $post[flags] && continue

					fname=$(date -d "${post[date]}" +'%Y%m%d%H%M%S')-$post[id]

					_zb_template fragment_post.html > ~/.zblog/content/cache/fragments/$fname

					cp ~/.zblog/content/posts/$p ~/.zblog/content/cache/posts/

					for tag in ${(s:, :)post[tags]}; do
						tagpath=~/.zblog/content/cache/tags/$tag
						mkdir -p $tagpath
						ln -s ~/.zblog/content/cache/fragments/$fname $tagpath/$fname
					done
				fi
			done

			# build archives bit
			for p in $(ls -vr ~/.zblog/content/cache/fragments); do
				archives=($archives ${=$(date -d "$(_zb_field date $p)" +"%Y %Y/%m %Y/%m/%d")})
			done

			# build tag cloud fragment
			tags=
			count[tags]=$(ls -v ~/.zblog/content/cache/tags | wc -l)
			for tag in $(ls -v ~/.zblog/content/cache/tags); do
				[[ $(ls -v ~/.zblog/content/cache/tags/$tag | wc -l) -eq 0 ]] && continue
				tags=($tags $tag)
				weight=$((($(ls -v ~/.zblog/content/cache/tags/$tag | wc -l).0 / $count[tags]) + 0.5))
				fragment[tags]+="<li><a href=\"/tags/$tag/\" style=\"font-size:${weight}0em\">$tag</a></li>"
			done
			fragment[tags]="<ul>$fragment[tags]</ul>"

			# build recent posts fragment
			for p in $(ls -v -r ~/.zblog/content/cache/fragments/* | head -n $blog[recent-posts]); do
				_zb_parse_post $p
				fragment[recent-posts]+="<li><a href=\"$post[permalink]\">$(_zb_escape <<< $post[title])</a></li>"
			done
			fragment[recent-posts]="<ul>$fragment[recent-posts]</ul>"

			# build archives fragment
			for p in $archives; do
				[[ ${#p} -gt 7 ]] && continue
				fragment[archives]+="<li><a href=\"/archives/$p/\">$p</a></li>"
			done
			fragment[archives]="<ul>$fragment[archives]</ul>"

			# build links fragment
			fragment[links]=""
			for link in ${(k)links}; do
				fragment[links]+="<li><a href=\"$links[$link]\">$link</a></li>"
			done
			fragment[links]="<ul>$fragment[links]</ul>"

			local date

			# iterate through fragments (in order) and build their pages
			content=(post 1)
			posts=($(ls -v ~/.zblog/content/cache/fragments/))
			count[posts]=${#posts}
			i=0
			for p in $posts; do
				(( i++ ))

				_zb_parse_post $p

				print $post[permalink]
				date=$(date -d "$post[date]" +"%Y/%m/%d")

				page=($(sed 's/\([0-9]\+\)\/\([0-9]\+\)\/\([0-9]\+\)/year \1 month \2 day \3/' <<< $date))

				page[previous]=$(_zb_permalink $posts[((i-1))])
				page[next]=$(_zb_permalink $posts[((i+1))])

				fragment[posts]=$(_zb_template fragment_post.html)
				page[content]=$(_zb_template content_post.html)

				mkdir -p ~/.zblog/content/blog/$post[permalink]
				_zb_template layout.html > ~/.zblog/content/blog/$post[permalink]/index.html
			done
			post=

			# build archive pages
			print /archives/
			content=(archive 1)
			page=()
			posts=($(ls -v -r ~/.zblog/content/cache/fragments/*))
			_zb_archives archives
			for archive in $archives; do
				print /archives/$archive/
				page=($(sed 's/\([0-9]\+\)/year \1/; s/\/\([0-9]\+\)/ month \1/; s/\/\([0-9]\+\)/ day \1/' <<< $archive))
				posts=($(ls -v -r ~/.zblog/content/cache/fragments/${archive//\//}*))
				_zb_archives archives/$archive
			done

			# build tag pages
			page=()
			content=(tag 1)
			for tag in $tags; do
				print /tags/$tag/
				posts=($(ls -v -r ~/.zblog/content/cache/tags/$tag/*))
				_zb_archives tags/$tag
			done

			# build main page
			content=(home 1)
			print /
			if [[ $(ls ~/.zblog/content/cache/fragments/ | wc -l) -gt $blog[posts] ]]; then page=(next /archives/p1/); else page=(); fi
			fragment[posts]=$(for j in $(ls -v -r ~/.zblog/content/cache/fragments/ | head -n $blog[posts]); do <~/.zblog/content/cache/fragments/$j; done)
			page[content]=$(_zb_template content_post.html)
			_zb_template layout.html > ~/.zblog/content/blog/index.html;;

		push) eval $blog[ftp_cmd];;

		*|help) ([[ -z $1 || $1 = help ]] && _zb_help $2) || (print "Unknown action: $1\n" && _zb_help);;
	esac
}

# vim: set ft=zsh :
