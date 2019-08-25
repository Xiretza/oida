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

_unshare_umount_R () {
	if findmnt "$1" >/dev/null; then
		umount -R "$1"
	fi
}

# Usage: unshare_rootro [-w WORKDIR] [-n]
#
# Unshare the mount and (optionally) the network namespaces and remount (almost)
# all filesystems read-only. The structure of the host's mounts is preserved,
# only the rw status of each mountpoint is changed.
#
# Writable directories in the new mount namespace:
# - /run: A fresh tmpfs is mounted here
# - /tmp: The host /tmp dir (rw)
# - WORKDIR: If given has it's rw status preserved
#
# Options:
# - if `-n` is given the network namespace is also unshared,
# - if `-w WORKDIR` is given the direcrory WORKDIR's writeability is preserved.
#
# Environment
# - in $RUNDIR (see oida-rundir.sh)
# - in $host_rw_ns[mnt]
unshare_rootro () {
	local workdir ns nss mntns netns flag dir
	workdir=
	nss=( ) # additional namespaces to unshare

	mntns=$RUNDIR/mntns; touch "$mntns"
	netns=$RUNDIR/netns; touch "$netns"
	cleanup "$mntns" "$netns"

	while getopts nw: flag; do
            case "$flag" in
                w) workdir=$OPTARG;;
		n) nss+=( net );;
                \?) exit 1;;
                *)  ;;
            esac
        done
        shift $(( OPTIND - 1))

	# Ok so, bind mounting the mnt namespace reference-file from inside the
	# new mount namespace (i.e. after `unshare mnt`) doesn't make a lick of
	# sense since this new mount won't show up in the parent namespace. For
	# one because we made /run/encim private and also the kernel doesn't
	# allow mounting the mnt reference into itself(!). This is to avoid
	# reference counting loops in the kernel apparently.
	#
	# As a workaround we simply use a trick from util-linux's unshare: fork
	# a child while still running in the parent namespace and have it wait
	# until we unsare()d and then mount our reference to /run/encim.
	coproc unshare_wait_parent {
		read -r # wait until unshare() hapend in parent
		# Note: '$$' expands to the main shell's pid, not the subshell
		mount -o bind /proc/$$/ns/mnt "$mntns"
	}

	for ns in "${nss[@]}"; do
		unshare "$ns"
		cleanup_ns_mount "${host_rw_ns[mnt]}" "$netns"
		mount -o bind /proc/$$/ns/net "$netns"
	done

	unshare mnt
	cleanup_ns_mount "${host_rw_ns[mnt]}" "$mntns"
	echo >&${unshare_wait_parent[1]}

	# false positive, assigned by `coproc`
	# shellcheck disable=SC2154
	wait $unshare_wait_parent_PID

	umount -R "$RUNDIR_MNT"

	cwd=$PWD
	rwroot=$(cd / || die "cd failed"; mktemp -d -p ./tmp 'rootro.XXXXXXXX')

	mount --make-rprivate /

	# Note: rbind,ro only makes the toplevel directory ro, this is even
	# documented in the manpage. So we have to do it manually.
	mount -o rbind / /mnt
	findmnt -R /mnt -l -n -o TARGET | \
		while IFS= read -r path; do
			mount -o remount,bind,ro "$path"
		done

	if [ -n "$workdir" ]; then
		_unshare_umount_R /mnt/"$workdir"
		mount --bind "$workdir" /mnt/"$workdir"
	fi

	# Can't remove this: umount needs to write to /run/mount/utab
	_unshare_umount_R /mnt/run;  mount -ttmpfs tmpfs  /mnt/run

	_unshare_umount_R /mnt/tmp;  mount --bind /tmp    /mnt/tmp

	mount -o remount,bind,ro /mnt/sys
	mount -o remount,bind,ro /mnt/dev
	mount -o remount,bind,ro /mnt/proc

	cd /mnt || die "cd failed"
	pivot_root . "$rwroot"
	cd / || die "cd falied" # recommended by manpage

	umount -l -R "$rwroot"
	rmdir "$rwroot"

	cd "$cwd" || die "cd failed"
}
