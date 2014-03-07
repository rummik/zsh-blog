#!/bin/zsh

function -blog-transport-ftp {
	autoload -U zfinit; zfinit

	if zfopen -1 "$ftp[host]" "$ftp[user]" "$ftp[pass]"; then
		[[ -z $(zfls "$ftp[root]") ]] &&
			zfmkdir

		zfcd "$ftp[root]"
		zfput -r $0
		zfclose
	fi
}
