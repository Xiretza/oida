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

##
# The [in module] manages the mount namespace used to construct the target
# filesystem and allows the user to execute commands in it.

_IN_FSTAB=

# Usage: _in_fstab FSTAB  CMD [ARG...]
#
# Mounts filesystems in FSTAB in order then executes CMD and finally cleans up
# mounts in reverse order.
_in_fstab () {
	local -; set -u -e
	local fstab rv

	fstab="$1"; shift

	printf '%s' "$fstab" | while read -r dev dir opt typ; do
	    mkdir -p "$dir"
	    mount $opt $typ "$dev" "$dir"
	done

	"$@"; rv=$?

	printf '%s' "$fstab" | tac | while read -r dev dir opt typ; do
	    umount "$dir"
	done

	return "$rv"
}

# Usage: _in_runas [-R CHROOT_DIR] [-C CHDIR] [-F FSTAB] [-u USER] -- [ENVVAR=VAR...] CMD [ARG...]
_in_runas () {
	local -; set -e -u $(dbg 10 +x:-x)
	local root chdir fstab user
	root=/
	chdir="$PWD"
	fstab=
	user=

	while getopts 'R:C:F:u:' flag; do
            case "$flag" in
                R) root="$OPTARG";;
                C) chdir="$OPTARG";;
		F) fstab="$OPTARG";;
		u) user="$OPTARG";;
                \?) printf '%s\n' "$flag"; exit 1;;
                *)  printf '%s\n' "$flag";;
            esac
        done
        shift $(( OPTIND - 1))

	set -- env -- "$@"

	if [ -n "$user" ]; then
		# OK this is a tricky one. The -c argument is single quoted so
		# we can use it as a mini script.
		#shellcheck disable=SC2016
		set -- runuser -s /bin/sh -c 'cd "$1" && shift && exec "$@"' - "$user" -- sh "$chdir" "$@"
	else
		set -- "$@"
	fi

	if [ x"$root" != x"/" ]; then
		set -- chroot "$root" "$@"
	else
		set -- "$@"
	fi

	if [ "$fstab" ]; then
		_in_fstab "$fstab" "$@"
	else
		"$@"
	fi
}

# Usage: in_target CMD [ARG...]
#
# Run command with target mounts defined with `in_target_mount` and overlays
# defined using `overlay_create` mounted.
#
# Environmnet:
#  - in $OUTDIR
#  - in $_IN_FSTAB
#  - in $OVERLAY_FSTAB
in_target () {
	_in_runas -F "${OVERLAY_FSTAB}${_IN_FSTAB}" "$@"
}

# Usage: in_target_overlay CMD [ARG...]
#
# Same as `in_target` but only overlay is available.
#
# Environment:
#  - in $OVERLAY_FSTAB
in_target_overlay () {
	# shellcheck disable=SC2016
	_in_runas -F "${OVERLAY_FSTAB}" "$@"
}

# Usage: in_target_chroot [-u USER] [ENVAR=value...] CMD [ARG...]
#
# Run command in target chroot.
#
# Environment:
#  - in $OVERLAY_FSTAB
#  - in $_IN_FSTAB
in_target_chroot () {
	_in_runas -R "$OUTDIR/rootfs.mnt/" \
		  -C / \
		  -F "${OVERLAY_FSTAB}${_IN_FSTAB}" \
		  "$@"
}

# Usage: in_target_mount [-o OPTIONS] [-t FSTYPE] DEVICE DIR
#
# Make a mount point available in future calls to `in_target` and
# `in_target_chroot`.
#
# Environment:
#  - inout $_IN_FSTAB
in_target_mount () {
	local -; set -u $(dbg 10 +x:-x)

	local typ opt dev dir
	typ=
        opt=

	while getopts o:t: f; do
            case $f in
                t) typ=$OPTARG;;
                o) opt=$OPTARG;;
                \?) exit 1;;
                *)  ;;
            esac
        done
        shift $(( OPTIND - 1))

	readonly dev="$1"; shift || exit 1
	readonly dir="$OUTDIR"/rootfs.mnt/"$1"; shift || exit 1

	_IN_FSTAB="${_IN_FSTAB}$dev $dir ${typ:+-t $typ} ${opt:+-o $opt}
"
}
