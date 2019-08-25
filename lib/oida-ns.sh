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

# Usage: ns_open FD_VAR= [mnt|net|cgroup..]...
#
# Open the given types of namespace references from /proc/self/ns and place them
# in the associative array named by FD_VAR. We do it this way because string
# expansion forces a subshell which would make opening the file descriptors
# futile, also being able to reference a specific type to ns is useful!
ns_open () {
	local var ty nss fd
	var=$1; shift
	declare -Ag "$var"
	nss=(   )
	for ty in $@; do
		exec {fd}<"/proc/self/ns/$ty"
		eval "$var[\$ty]=\$fd"
	done

	declare -p $var
}

# Usage: ns_close FD...
ns_close () {
	local fd

	for fd in $@; do
		echo $fd
		ls -l /proc/self/fd
		exec {fd}<&-
	done
}
