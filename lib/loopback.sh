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


# Usage: loopback_bind FILE LO_VAR=
#
# Map the disk image FILE to a loopback device. The loop device node name will
# be bound to the shell variable LO_VAR.
#
# Cleanup:
#   The loopback device will be removed on termination by the [cleanup module].
loopback_create () {
	local -; set -u -x
	local file var
	file="$1"; shift
	var="$1"; shift

	local lo
	lo="$(losetup --show -P -f "$file")"
	cleanup_cmd losetup -d "$lo"

	eval "$var=\$lo"
}
