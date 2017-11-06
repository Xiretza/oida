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


# Usage: unshare_rootro [-w WORKDIR] [-n] ENVVAR=VAL CMD [ARG...]
#
# Unshare the mount namespace and remounts all mounted filesystems read-only.
#
# Options:
# - if `-n` is given the network namespace is also unshared,
# - if `-w WORKDIR` is given the direcrory WORKDIRs writeability is preserved.
#
# Note: Uses FD 3 internally
unshare_rootro () {
	local -; set -u # +x
	local workdir newnet mntns netns flag rv
	workdir=
	newnet=

	cleanup_mount /run/encim
	cleanup /run/encim

	if ! findmnt /run/encim >/dev/null 2>&1; then
		mkdir -p /run/encim
		mount --bind /run/encim /run/encim
		mount --make-private /run/encim
	fi

	mntns=$(mktemp /run/encim/mountns.XXXXXXX)
	netns=$(mktemp /run/encim/netns.XXXXXXX)

	while getopts nw: flag; do
            case "$flag" in
                w) workdir=$OPTARG;;
		n) newnet=--net="$netns";;
                \?) exit 1;;
                *)  ;;
            esac
        done
        shift $(( OPTIND - 1))

	cleanup_mount "$mntns" "$netns"
	cleanup       "$mntns" "$netns"

    	exec 3<&0
	# we want $newnet to expand to nothing when the -n flag is not set
	# shellcheck disable=SC2086
	command unshare --mount="$mntns" $newnet -- env -- PS4="+(us-ro)    " sh -s -x "$PWD" "$workdir" "$@" <<-"EOF"
		set -eu
		umount_R () {
			if findmnt "$1" >/dev/null; then
				umount -R "$1"
			fi
		}

		cwd="$1"; shift
		wd="$1"; shift

		mount -o rbind,ro / /mnt

		if [ -n "$wd" ]; then
			umount_R /mnt/"$wd"
			mount --bind "$wd" /mnt/"$wd"
		fi

		umount_R /mnt/run;  mount -ttmpfs tmpfs  /mnt/run
		umount_R /mnt/tmp;  mount --bind /tmp    /mnt/tmp

		umount_R /mnt/sys;  mount --move /sys    /mnt/sys
		umount_R /mnt/dev;  mount --move /dev    /mnt/dev
		umount_R /mnt/proc; mount --move /proc   /mnt/proc

		cd /mnt
		pivot_root . media
		umount -l -R /media

		cd "$cwd"
		exec env -- PS4='+ ' "$@" <&3
	EOF
	rv=$?
	exec 3<&-
	return "$rv"
}
