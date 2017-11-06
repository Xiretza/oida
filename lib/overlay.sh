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

#- FSTAB for use with `_in_fstab`.
export OVERLAY_FSTAB=

_OVERLAYS=

# Usage: overlay_create OVERLAY_NAME
#
# Environment:
# - in $OUTDIR
# - out OVERLAY_FSTAB
# - inout $_OVERLAYS
overlay_create_cached () {
	local -; set -u
	local overlay
	overlay="$1"; shift

	if [ -z "$_OVERLAYS" ]; then
		_OVERLAYS="$OUTDIR/$overlay"
	else
		_OVERLAYS="$OUTDIR/${overlay}.overlay:$_OVERLAYS"
		OVERLAY_FSTAB="overlay $OUTDIR/rootfs.mnt/ -t overlay -o lowerdir=$_OVERLAYS,upperdir=$OUTDIR/$overlay.overlay,workdir=$OUTDIR/workdir
"
		mkdir -p "$OUTDIR"/"$overlay".overlay
	fi

	mkdir -p "$OUTDIR"/workdir
}

overlay_create () {
    local -; set -u
    local overlay
    overlay="$1"; shift

    if [ -d "$OUTDIR"/"$overlay".overlay ]; then
	    rm -r "$OUTDIR"/"$overlay".overlay
    fi

    overlay_create_cached "$overlay"
}
