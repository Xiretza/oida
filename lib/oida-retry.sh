#!/bin/sh
# Copyright (C) 2017  Daniel Gröber <dxld@darkboxed.org>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


# Usage: retry MAX_TRIES [DELAY] -- CMD [ARG...]
retry () {
    local i
    i=0

    local max_tries
    max_tries="$1"; shift

    local delay
    delay=1

    if [ x"$1" != x"--" ]; then
	    delay="$1"; shift
    fi

    [ x"$1" = x"--" ] || exit 1; shift

    while [ "$i" -lt "$max_tries" ] && ! ( "$@" ); do
	sleep "$delay"
	i=$((i + 1))
    done

    [ "$i" -ge "$max_tries" ] && return 1
    return 0
}
