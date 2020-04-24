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

##
# The [ns module] allows saving, copying and restoring the namespace context of
# the shell.

# Usage: ns_open FD_ARRAY= NS_DIR [mnt|net|cgroup..]...
#
# Open the given types of namespace references from /proc/self/ns and place
# them in the associative array named by FD_ARRAY. We do it this way
# because string expansion forces a subshell which would make opening the
# file descriptors futile, also being able to reference a specific type to
# ns is useful!
ns_open () {
	[ $# -gt 2 ] || {
		echo "Error: ns_open: Not enough arguments">&2
		return 1
	}

	local var dir ty nss fd
	var=$1; shift
	dir=$1; shift
	declare -Ag "$var"
	nss=(  )
	for ty in $@; do
		exec {fd}<"$dir/$ty"
		eval "$var[\$ty]=\$fd"
	done
}

# Usage: ns_close FD_ARRAY
#
# Close the file descriptors in the named array and unset the array.
#
# Example:
#   ns_open NS_FDs /proc/self/ns mnt net
#   ns_close NS_FDs
ns_close () {
	local var fd
	[ $# -le 1 ] || { echo "Error: Usage: ns_close FD_ARRAY">&2; return 1; }
	var=$1; shift
	for fd in "${!var[@]}"; do
		#echo $fd
		#ls -l /proc/self/fd
		exec {fd}<&-
	done
	unset "$var"
}

# Usage: ns_mount SRC_DIR TARGET_DIR NS_TYPE...
#
# Mount the namespace references with the given NS_TYPEs from SRC_DIR to
# corresponding files in DEST_DIR.
#
# Example:
#   ns_mount /proc/self/ns /some/dir mnt net
#
ns_mount () {
	[ $# -le 2 ] || \
		{ echo "Error: ns_mount: Too many arguments">&2; return 1; }

	local src dest
	src=$1; shift
	dest=$1; shift

	mkdir -p "$dest"
	for ty in $@; do
		touch "$dest/$ty"
		mount -o bind "$src/$ty" "$dest/$ty"
	done
}
