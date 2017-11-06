#!/bin/sh
set -e

[ $# -lt 1 ] && { echo "Usage: $0 HOSTNAME CMD [ARG...]"; exit 1; }

hostname="$1"; shift

_waitprompt () {
    if [ -n "$1" ]; then
	    timeout "$1" sed '/#@%/q' <&3 >&2
    else
	sed '/#@%/q' <&3 >&2
    fi

    if [ $? -eq 124 ]; then
	    return 124
    fi
}

_open () {
    rm -f /run/"$hostname"-ttyS0.rx /run/"$hostname"-ttyS0.tx
    mkfifo /run/"$hostname"-ttyS0.rx /run/"$hostname"-ttyS0.tx

    socat STDIO UNIX-CONNECT:/run/encim-ttyS0.unix \
	  >/run/"$hostname"-ttyS0.rx </run/"$hostname"-ttyS0.tx &

    exec 3</run/"$hostname"-ttyS0.rx
    exec 4>/run/"$hostname"-ttyS0.tx

    sleep 1
}

_close () {
    exec 3<&-
    exec 4>&-
}

login () {
    local -; set +e

    timeout 10 sed -e '/^Linux [a-zA-Z0-9]/q' -e '/^Login incorrect/q 101' \
	<&3 >&2 & pid=$!

    printf 'root\r' >&4
    sleep 5
    printf 'root\r' >&4

    wait "$pid"

    if [ $? -eq 101 ]; then
	    exit 101
    elif [ $? -eq 124 ]; then
	    exit 124
    fi

    sleep 0.5

    (
	_waitprompt
	_waitprompt
	_waitprompt
    ) & pid=$!

    # shellcheck disable=SC2016
    printf '%s\r' 'PS1=$(printf "%s\nx" "#@%") ; PS1=${PS1%?}' >&4

    wait "$pid"

    _waitprompt 1 & pid=$!
    printf '%s\r' "stty -echo" >&4
    wait "$pid"

    _waitprompt 1 & pid=$!
    printf '%s\r' 'PS2=' >&4
    wait "$pid"
}

logout () {
    timeout 4 sed -r '/^Debian|^Login|logout/q'<&3 >&2 & pid=$!
    printf '\003' >&4
    sleep 1
    printf '\004' >&4
    wait "$pid"

}

begin () {
    logout

    _close
    sleep 4
    _open

    login
}

end () {
    _waitprompt 1 || true
    printf '\003\rexit\r' >&4
}

cmd () {
    b64=$(printf "%s\n" "$*" 'exit $?' | base64) >&4

    ( sed -n -e '/#@%/Q' -e 'p' <&3 | base64 -d 2>/dev/null | awk 'BEGIN { FS = "="; i=0; }  { if(i > 0 && t) { print t; t = ""; }  if(/^RV=/) { i++; t = $0; rv = $2; } else { print $0; } }  END { exit rv; }' ) & pid=$!
    printf '%s\r' 'printf "%s\n" '"$b64"' | base64 -d 2>/dev/null | ( sh 2>/dev/null; printf "%s\n" "RV=$?" </dev/null ) | base64 2>/dev/null' >&4 ;
    wait $pid
}

_open

"$@"
