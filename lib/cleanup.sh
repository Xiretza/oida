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


CLEANUP_CMDS=
CLEANUP_FILES=
# Usage: cleanup [PATH...]
#
# Add files or directories to cleanup list.
cleanup () {
	local -; set +x
	CLEANUP_FILES=$(
	    set -f
	    IFS='
'
	    printf '%s\n' "$@" $CLEANUP_FILES
	)
}

# Usage: cleanup_cmd COMMAND [ARG...]
#
# Add commands to call to the list of cleanup actions.
cleanup_cmd () {
	local -; set +x
	CLEANUP_CMDS="$*
$CLEANUP_CMDS"
}

cleanup_mount () {
	local -; set +x
	local mnt
	for mnt in "$@"; do
	    cleanup_cmd _cleanup_do_mount "$mnt"
	done
}

_cleanup_do_mount () {
	local mnt
	mnt="$1"; shift

	if findmnt -k "$mnt" >/dev/null 2>&1; then
	    umount "$mnt" || true
	fi
}

_cleanup_do_files () {
	local -
	set -f

	local IFS
	IFS='
'
	for path in $CLEANUP_FILES; do
	    set +f
	    IFS=

	    for p in $path; do
		    printf 'Cleaning %s\n' "$p" >&2
		    if [ -d "$p" ]; then
		    	rmdir "$p" || true
		    else
		    	rm -f "$p" || true
		    fi
	    done
	done

	CLEANUP_FILES=
}

_cleanup_do_cmds () {
	local IFS
	IFS='
'
	for cmd in $CLEANUP_CMDS; do
	    printf 'Cleanup: $ %s\n' "$cmd" >&2
	    IFS=' 	'
	    $cmd
	done
	CLEANUP_CMDS=
}

cleanup_do () {
	local -; set +x
	_cleanup_do_cmds
	_cleanup_do_files
}

trap 'cleanup_do; trap - INT; kill -INT $$' INT
trap 'cleanup_do; trap - TERM; kill -TERM $$' TERM
trap 'cleanup_do; trap - EXIT' EXIT
