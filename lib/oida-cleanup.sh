#!/bin/bash
# Copyright (C) 2017-2019  Daniel Gröber <dxld@darkboxed.org>
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

# These vars are simulating an array of lists by storing idx, len in seperate
# arrays and using ${array[@]:$idx:$len} for extraction.
# See test/unit/nested-array.sh
CLEANUP=()
CLEANUP_idx=()
CLEANUP_len=()

# Usage: cleanup [PATH...]
#
# Add files or directories to cleanup list.
cleanup () {
	local f
	for f in "$@"; do
		_cleanup_cmd _cleanup_do_file "$f"
	done
}

# Usage: cleanup_cmd COMMAND [ARG...]
#
# Add commands to call to the list of cleanup actions.
cleanup_cmd () {
	_cleanup_cmd _cleanup_do_cmd "$@"
}

_cleanup_cmd () {
	local -; set +x
	CLEANUP_idx+=( "${#CLEANUP[@]}" )
	CLEANUP_len+=( $# )
	CLEANUP+=( "$@" )
}

cleanup_mount () {
	local mnt
	for mnt in "$@"; do
		_cleanup_cmd cleanup_do_mount "$mnt"
	done
}

cleanup_ns_mount () {
	local ns mnt
	ns=$1; shift

	for mnt in "$@"; do
		_cleanup_cmd _cleanup_do_ns_mount "$ns" "$mnt"
	done
}

cleanup_do_mount () {
	local mnt
	mnt="$1"; shift

	if findmnt -k "$mnt" >/dev/null 2>&1; then
		umount "$mnt" || true
	fi
}

_cleanup_do_ns_mount () ( #< note the subshell parens!
	local ns mnt
	ns=$1; shift
	mnt=$1; shift

	IFS=' ' setns $ns
	cleanup_do_mount "$mnt"
)

_cleanup_do_file () {
	printf 'Cleaning %s\n' "$1" >&2
	if [ -d "$1" ]; then
		rmdir "$1" || true
	else
		rm -f "$1" || true
	fi
}

_cleanup_do_cmd () {
	printf 'Cleanup: $ %s\n' "$*" >&2
	"$@"
}

_cleanup_debug_print () {
	printf '%s, ' "${CLEANUP_idx[@]}"; echo
	printf '%s, ' "${CLEANUP_len[@]}"; echo
	printf '"%s", ' "${CLEANUP[@]}"; echo
}

cleanup_do () {
	for i in "${!CLEANUP_idx[@]}"; do
		i=$(( ${#CLEANUP_idx[@]} - 1 - $i ))
		set -- "${CLEANUP[@]:${CLEANUP_idx[$i]}:${CLEANUP_len[$i]}}"
		# printf '%s\n' "$*" # debug
		"$@"
	done

	CLEANUP=()
	CLEANUP_idx=()
	CLEANUP_len=()
}

trap 'cleanup_do; trap - INT; kill -INT $$' INT
trap 'cleanup_do; trap - TERM; kill -TERM $$' TERM
trap 'cleanup_do; trap - EXIT' EXIT
