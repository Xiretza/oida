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

# Usage:
# Example: sh $(dbg 7 +x:-x) <<EOF...
dbg () {
	local loglevel
	loglevel="$1"

	local IFS
	IFS=:
	set -- $2
	if [ "${DEBUG:-0}" -ge "${loglevel:-0}" ]; then
		printf '%s' "$2"
	else
		printf '%s' "$1"
	fi
}
