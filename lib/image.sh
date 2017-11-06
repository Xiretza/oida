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


# Usage: image_create IMAGE_NAME SIZE_MB IMAGE_VAR= MNT_VAR=
#
# Environment:
#  - in $OUTDIR
#
# Create (or recreate) a sparse disk image in OUTDIR. The shell variables
# IMAGE_VAR and MNT_VAR will be set to the image's path and a suitable mount
# point respectively.
image_create () {
	local -; set -e +x

	local image_name size image_var mnt_var
	image_name="$1"; shift
	size="$1"; shift
	image_var="$1"; shift
	mnt_var="$1"; shift

	local image mnt
	image="$OUTDIR/${image_name}.image"
	mnt="$OUTDIR/${image_name}.mnt"

	mkdir -p "$mnt"

	eval "$image_var=\$image"
	eval "$mnt_var=\$mnt"

	# MiB
	dd if=/dev/zero of="$image" \
	   bs=1024 seek=$(( ( 1024 * size ) - 1)) count=1
}
