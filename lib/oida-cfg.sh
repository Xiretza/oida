#!/bin/bash
# Copyright (C) 2019,2020  Daniel Gröber <dxld@darkboxed.org>
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


# Usage: cfg VAR DEFAULT
#
# Textually equivalent to:
#
#   VAR=${VAR:-DEFAULT}
#
# Declare a configuration parameter. If ${VAR} is currently unset or null,
# for example it was undefined in the environment, it is set to
# DEFAULT. The resulting shell variable is always made non-exported and
# readonly.
cfg () {
	local -; set +x

	[ $# -le 2 ] || { echo "cfg: Too many arguments"; return 1; }
	local var="$1" default="$2"
	declare -n val=$var #< create nameref to $var so we don't have to
			    # eval below
	val=${val:-$default}
	declare -g +x -r "$var" #< un-export and make read-only
}

# Usage: sed_cfg SED_ARGS...
#
# Construct a sed command line to replace occurrences of each variable in the
# current shell session begining with `CFG_` by their value and run it with
# SED_ARGS appended.
#
# Examples:
#
#   $ sed_cfg -i somefile.foo
#   $ cat somefile.bla | sed_cfg > /there/somefile.bla
#
# With CFG_FOO=123 in the current shell session `sed_cfg -i somefile` is
# equivalent to:
#
#   sed -e sCFG_FOO123g -i somefile
#
# Note that we use  (ASCII GS) as the sed 's' command delimiter to make a
# conflict with user code very unlikely. If the variable value contains GS
# an error is returned.
sed_cfg () {
    local -; set +x

    for v in "${!CFG_@}"; do
	    if [[ "${!v}" == ** ]]; then
		    echo "Error: sed_cfg: ${!v} must not contain an ASCII GS aka \\x1F aka group separator!" >&2
		    exit 1
	    fi
	    set -- -e "s${v}${!v}g" "$@"
    done

    sed "$@"
}
