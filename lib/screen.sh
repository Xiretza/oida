screen_create () {
    local -; set -e -u -x

    local name name_var
    name="$(mktemp -u screen.XXXXXXX)"
    name_var="$1"; shift

    eval "$name_var=\$name"

    cleanup_cmd screen -S "$name" -X quit
    screen -S "$name" -d -m

    screen -S "$name" -X hardstatus on
    screen -S "$name" -X hardstatus alwayslastline
    screen -S "$name" -X hardstatus string "%w"
}

screen_window_create () {
    true
}
