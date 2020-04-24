#!/bin/bash
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

# DEPENDS: oida-cleanup.sh

# Usage: rundir_setup
#
# Setup /run/encim so it can be used for mounting namespace references and other
# runtime data.
#
# Environment:
#  - out $RUNDIR: A new unique path for this session to use for ephemeral
#    runtime data.
#  - in $host_rw_ns[mnt]
rundir_setup () {
	if mkdir /run/encim >/dev/null 2>&1; then
		cleanup /run/encim
	fi

	if ! findmnt /run/encim >/dev/null 2>&1 \
		   && flock --nonblock /run/encim \
			    mount --bind /run/encim /run/encim
	then
		cleanup_ns_mount "${host_rw_ns[mnt]}" /run/encim
	fi

	mount --make-private /run/encim

	RUNDIR=$(mktemp -d /run/encim/$$.XXXXXXX)
	cleanup "$RUNDIR"
}

# Usage: rundir_cleanup_leftover
#
# Remove any directories in /run/encim who's corresponding processes are no
# longer alive. This is most likely racy be prepared for it to fail.
rundir_cleanup_leftover () ( #< note the subshell parens
	local -; shopt -s nullglob
	if [ ! -d /run/encim/ ]; then
		return 0
	fi

	cd /run/encim/ || die "cd failed"

	for d in *.*; do
		if [ ! -d /proc/"${d%.*}" ]; then
			cleanup_do_mount "$d"/netns
			cleanup_do_mount "$d"/mntns

			rm -f "$d"/netns
			rm -f "$d"/mntns

			rm -r "$d"
		fi
	done
)
