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


# Usage: tgt_install [OPTIONS...] PATH
#
# Environment:
#  - in $DATADIR
#  - in $OUTDIR
#
# Installs PATH from $DATADIR into $OUTDIR/rootfs.mnt, defaults to -rw-r--r--
# permissions. Pass GNU `install` options in OPTIONS to modify permissions.
tgt_install () {
    	local -; set -u
	local path

	[ $# -lt 1 ] && return 1

	path="$1"; shift

	install -m644 "$@" -D "$DATADIR"/"$path" "$OUTDIR"/rootfs.mnt/"$path"
}
