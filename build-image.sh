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

set -u -e

### BEGIN CONFIG ###
# The variables declared in this block are intended to be (text) replaced when
# installing this program systemwide.
#
# You can use something like this to do the replacement:
#   sed -n '/BEGIN CONFIG/,/END CONFIG/{s/^LIBDIR=.*/LIBDIR=FOOBAR/;p}'

# TODO: remove; this concept doesn't make sense when installed systemwide
TOPDIR="$(realpath "$(dirname "$0")")"
readonly TOPDIR
export TOPDIR

LIBDIR="$(realpath "$(dirname "$0")"/lib)"
readonly LIBDIR
export LIBDIR

unset BASH_LOADABLES_PATH
BASH_LOADABLES_PATH=$TOPDIR/builtins
readonly BASH_LOADABLES_PATH
### END CONFIG ###

die () {
	printf '%s\n' "$@" >&2
	exit 1
}

usage () {
	die "Usage: $0 build SCRIPT OUTDIR | $0 test SCRIPT OUTDIR"
}

cmd_build () {
	export SCRIPT="$1"; readonly SCRIPT; shift
	export OUTDIR="$1"; readonly OUTDIR; shift

	# shellcheck source=lib/oida-debug.sh
	. oida-debug.sh
	# shellcheck source=lib/oida-cleanup.sh
	. oida-cleanup.sh
	# shellcheck source=lib/oida-builtins.sh
	. oida-builtins.sh
	# shellcheck source=lib/oida-rundir.sh
	. oida-rundir.sh
	# shellcheck source=lib/oida-unshare.sh
	. oida-unshare.sh

	# shellcheck source=lib/oida-ns.sh
	. oida-ns.sh

	[ x"$(id -u)" = x'0' ] || die "$0: Must run as root"

	#set "$(dbg 20 +x:-x)"

	# clean locale environment stuff
	eval export "$(env -i LANG=C.UTF-8 locale)"

	mkdir -p "$OUTDIR"

	ns_open host_rw_ns /proc/self/ns mnt

	rundir_cleanup_leftover
	rundir_setup

	unshare_rootro -w "$OUTDIR"

	ns_open host_ro_ns /proc/self/ns mnt net

	. "$SCRIPT"
}

cmd_test () {
	export SCRIPT="$1"; readonly SCRIPT; shift
	export WORKDIR="$1"; readonly WORKDIR; shift

	# shellcheck source=lib/oida-cleanup.sh
	. oida-cleanup.sh
	# shellcheck source=lib/oida-unshare.sh
	. oida-unshare.sh
	# shellcheck source=lib/oida-debug.sh
	. oida-debug.sh

	set "$(dbg 30 +x:-x)"
	PS4='+(tst)    '

	unshare_rootro -n

	. "$SCRIPT"

}

# This is to make using 'source' with unqualified script names work
PATH="$LIBDIR:$PATH"

if [ $# -lt 3 ]; then
	usage
fi

COMMAND=$1; readonly COMMAND; shift
case "$COMMAND" in
	build)  cmd_build "$@";;
	test)   cmd_test  "$@";;
esac
