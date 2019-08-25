#!/bin/sh
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

# Usage: overlay_mount SOURCE_DIR TARGET_DIR
#
# Mount an overlayfs at $TARGET_DIR, using $SOURCE_DIR as the lower (read-only)
# base to start from. New files will be written to '${TARGET_DIR}.overlay'.
#
# Note this simple wrapper only one allows one overlay mount per TARGET_DIR
# because of the naming convention.

overlay_mount () {
    local source target
    source="$1"; shift
    target="$1"; shift

    if [ -d "$target".overlay ]; then
	    rm -r "$target".overlay
    fi

    cleanup  "$target".overlay "$target".workdir
    mkdir -p "$target".overlay "$target".workdir

# TODO    cleanup_ns_mount  "$target"
    mount -t overlay overlay \
	  -o lowerdir="$source",upperdir="$target".overlay,workdir="$target".workdir \
	  "$target"
}
