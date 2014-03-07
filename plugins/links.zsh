local -a links

links=(
	Home /
)

function -blog-fragment-links {
	print '<ul class="blog-links">'
	for ((i=1; i<$#links; i+=2)); do
		print -r -- "<li><a href=\"${links[i]}\">${links[i+1]}</a></li>"
	done
	print '</ul>'
}
