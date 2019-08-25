#!/bin/bash

set -u

IFS=

array=()
idx=()
len=()

add () {
	idx+=( ${#array[@]} )
	len+=( $# )
	array+=( "$@" )
}

extract () {
	printf '"%s", ' "${array[@]:${idx[$1]}:${len[$1]}}"; echo .
}

add 1 "2 3" 4

add "a b" c d e

add foobar baz

printf '"%s", ' "${array[@]}"; echo .
printf '%s, ' "${idx[@]}"; echo .
printf '%s, ' "${len[@]}"; echo .
echo

extract 0
extract 1
extract 2

( extract 3 ) || echo idx=3 failed
