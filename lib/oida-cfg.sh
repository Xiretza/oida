#!/bin/bash
# Copyright (C) 2019  Daniel Gröber <dxld@darkboxed.org>
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


# Usage: cfg VAR:-DEFAULT
#
# Declare a configuration parameter. If if ${VAR} is currently unset, i.e. it
# was undefined in the environment, it is set to DEFAULT. In either case ${VAR}
# is made readonly.
cfg () {
    eval "unset _${1%%:*} ${1%%:*}; _${1%%:*}=\${$1}"
    eval "readonly ${1%%:*}=\"\$_${1%%:*}\"; unset _${1%%:*}"
}

# Usage: sed_cfg SED_ARGS
#
# Construct a sed command line to replace occurrences of each variable in the
# current shell session begining with `CFG_` by their value and run it with
# SED_ARGS appended.
#
# Examples:
#
#   $ sed_cfg -i somefile.foo
#   $ cat somefile.bla | sed_cfg > /there/somefile.bla
sed_cfg () {
    local -; set +x
    exec 3<&0
    set | grep ^CFG_ | (
	while read -r c; do
	    eval "v=\$${c%%=*}"
	    # shellcheck disable=SC2154
	    set -- -e "s,${c%%=*},$v," "$@"
	done
	sed "$@" <&3
    )
    exec 3<&-
}
