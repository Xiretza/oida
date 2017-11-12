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

set -e


export TOPDIR
readonly TOPDIR="$(realpath "$(dirname "$0")")"
export LIBDIR
readonly LIBDIR="$(realpath "$(dirname "$0")"/lib)"

die () {
	printf '%s\n' "$@" >&2
	exit 1
}

usage () {
	die "Usage: $0 WORKDIR SCRIPT"
}

if [ x"$1" = x'--unshared' ]; then
	UNSHARED_FLAG="$1"; shift
fi
export OUTDIR="$1"; shift || usage
export SCRIPT="$1"; shift || usage
if [ $# -ge 1 ]; then
	CMD="$1"; shift || usage
else
	CMD=run
fi

# shellcheck source=lib/cleanup.sh
. "$LIBDIR"/cleanup.sh
# shellcheck source=lib/unshare.sh
. "$LIBDIR"/unshare.sh
# shellcheck source=lib/in.sh
. "$LIBDIR"/in.sh
# shellcheck source=lib/overlay.sh
. "$LIBDIR"/overlay.sh

[ x"$(id -u)" = x'0' ] || die "$0: Must run as root"

mkdir -p "$OUTDIR"

if [ x"$UNSHARED_FLAG" != x'--unshared' ]; then
	unshare_rootro -w "$OUTDIR" sh "$0" --unshared "$OUTDIR" "$SCRIPT" "$CMD" "$@"
	exit $?
fi

mkdir -p "$OUTDIR"/rootfs.mnt

# clean locale environment stuff
eval export "$(env -i LANG=C.UTF-8 locale)"

run_step () {
	local mode cached user  old_IFS IFS
	mode=host

	if [ x"$step" != x"$opt" ]; then
		old_IFS="$IFS"
		IFS=','
		for o in $opt; do
		    IFS="$old_IFS"

		    case "$o" in
			(in_target_chroot)  mode="$o";;
			(in_target_overlay) mode="$o";;
			(in_target)         mode="$o";;
			(host)              mode="$o";;
			(image)             mode=host;;

			(overlay)           overlay_create "$step1";;
			(overlay_cached)    overlay_create_cached "$step1";;

			(*)                die "$0: Unknown step option '$o'";;
		    esac
		done
	fi

	case "$mode" in
	    (host)
		step "$step1" "$step";;

	    (in_*)
		printf 'Running [%s] step %s\n' "$opt" "$step" >&2

		{
			for import in $(imports); do
			    cat "$LIBDIR"/"$import"
			done

			cat "$SCRIPT"

			printf '\n%s\n' '"$@"'
		} | $mode  PS4="+($stepnum)    " sh -s step "$step1" "$step"
		;;

	esac
}

. $(realpath "$SCRIPT")

for import in $(imports); do
    . "$LIBDIR"/"$import"
done

for step0 in $(steps); do
    opt=${step0#*=}
    step1=${step0%%=*}

    stepnum=${step1%%-*}
    step=${step1#*-}

    case "$CMD" in
	(run) run_step ;;
    esac
done
