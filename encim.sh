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

set -e -u

### TODO:
## - parameterise gpg receiver address or just use only ultimately trusted key
## or something.
###
## - parameterise hostnames


readonly CONFIG_DEBIAN_RELEASE=stretch
readonly CONFIG_USERNAME=${CONFIG_USERNAME:-dxld}

# Get password from environment without exporting it further
unset _CONFIG_ROOT_PASSWORD CONFIG_ROOT_PASSWORD
_CONFIG_ROOT_PASSWORD=${CONFIG_ROOT_PASSWORD:-root}
CONFIG_ROOT_PASSWORD=$_CONFIG_ROOT_PASSWORD
unset _CONFIG_ROOT_PASSWORD

export DATADIR
readonly DATADIR="$(realpath "$TOPDIR"/encim-data)"

imports () {
	printf '%s\n' \
       	       cleanup.sh \
	       target.sh \
	       image.sh \
	       loopback.sh
}

boot_install_tgt () {
	mkdir -p /boot/grub/
	cp -a /usr/lib/grub/i386-pc /boot/grub/
	grub-mkimage \
		  --directory /usr/lib/grub/i386-pc \
		  --prefix /boot/grub \
		  --output /boot/grub/i386-pc/core.img \
		  --config /boot/grub/i386-pc/load.cfg \
		  --format i386-pc \
		  --compression auto \
		  --verbose \
		  part_msdos biosdisk gzio squash4 linux normal echo
}

boot_write_bootblock () {
	local lodev root
	readonly lodev="$1"; shift
	readonly root="$1"; shift

	cleanup_cmd umount -R "$root"

	mount "${lodev}p1" "$root"
	mount -t devtmpfs devtmpfs "$root"/dev
	mount -t proc     proc     "$root"/proc
	mount -t sysfs    sysfs    "$root"/sys

	chroot "$root" /usr/lib/grub/i386-pc/grub-bios-setup \
	       --directory=/boot/grub/i386-pc \
	       "$lodev"
}

steps () {
	printf '%s\n' \
		10-bootstrap=host,overlay_cached \
		\
		20-cleanup=in_target_chroot,overlay\
		\
		30-config=in_target,overlay \
		31-config-update=in_target_chroot \
		\
		40-packages=in_target_chroot,overlay \
		\
		50-bootloader=in_target_chroot,overlay \
		\
		90-disk=in_target_overlay
}

step () {

local - name; set -e -u
name="$1"; shift

case "$1" in

(bootstrap)
	if ! [ -e "$OUTDIR"/"$name"/bin/true ]; then
		debootstrap \
			--merged-usr \
			--include=linux-image-amd64,initramfs-tools \
			"$CONFIG_DEBIAN_RELEASE" "$OUTDIR"/"$name"
	fi

	in_target_mount -t proc     proc       /proc
	in_target_mount -t sysfs    sysfs      /sys
	in_target_mount -t devtmpfs devtmpfs   /dev
	in_target_mount -t devpts   devpts     /dev/pts
	in_target_mount -t tmpfs    tmpfs      /run
	in_target_mount -t tmpfs    tmpfs      /tmp
	in_target_mount -o bind,ro  "$DATADIR" /srv
	;;

(cleanup)
	ls -l / /etc
	rm -f /etc/resolv.conf
	rm /etc/hostname
	rm /var/cache/apt/archives/*.deb
	;;

(config)
	cp -dR --preserve=mode,timestamps --remove-destination \
	   "$DATADIR"/boot \
	   "$DATADIR"/etc \
	   "$DATADIR"/home \
	   "$DATADIR"/usr \
	   "$DATADIR"/var \
	   \
	   "$OUTDIR"/rootfs.mnt

	mv "$OUTDIR"/rootfs.mnt/home/user/ \
	   "$OUTDIR"/rootfs.mnt/home/"$CONFIG_USERNAME"

	chown -R 1000:1000 \
	      "$OUTDIR"/rootfs.mnt/home/"$CONFIG_USERNAME"

	echo "root:$CONFIG_ROOT_PASSWORD" \
		| chpasswd -c SHA512 -R "$OUTDIR"/rootfs.mnt
	useradd -m -U \
		-u 1000 \
		-s /bin/bash \
		-R "$OUTDIR"/rootfs.mnt \
		"$CONFIG_USERNAME"
	;;

(config-update)
	update-initramfs -u -v
	debconf-set-selections < /srv/debconf-db
	;;

(packages)
	# We want the package lists to expand to multiple elements, so:
	# shellcheck disable=SC2046
	DEBIAN_FRONTEND=noninteractive \
		apt-get install -y \
			grub-pc-bin \
			systemd-sysv \
			cloud-guest-utils \
			locales \
			dhcpcd5 \
			openssh-server \
			exim4-daemon-heavy \
			exim4-config \
			util-linux
	;;

(bootloader)
	mkdir -p /boot/grub/
	cp -a /usr/lib/grub/i386-pc /boot/grub/
	grub-mkimage \
		  --directory /usr/lib/grub/i386-pc \
		  --prefix /boot/grub \
		  --output /boot/grub/i386-pc/core.img \
		  --config /boot/grub/i386-pc/load.cfg \
		  --format i386-pc \
		  --compression auto \
		  --verbose \
		  part_msdos biosdisk gzio squash4 linux normal echo
	;;

(disk)
	image_create "$name" 1220 DISK_IMAGE DISK_IMAGE_MNT
	loopback_create "$DISK_IMAGE" DISK_LODEV
	# rootsize=$(( ( $(stat -c '%s' "$OUTDIR"/rootfs.mnt.squashfs) / 512 ) ))

	# SYNC WITH data/usr/local/lib/encim-swap-boot-partitions if changed
	sfdisk "$DISK_LODEV" <<-EOF
		1M, 512M   , L, *
		  , 512M   , L,
		  ,        , E,
		  , 32M    , L,
		  , 32M    , L,
		  , 128M   , L,
	EOF

	ROOTFS_LODEVP="${DISK_LODEV}p1"
	MAILVAR_LODEVP="${DISK_LODEV}p5"
	HOME_LODEVP="${DISK_LODEV}p7"

	# see debian bug #869771 about the last two options
	mksquashfs "$OUTDIR"/rootfs.mnt/ "$ROOTFS_LODEVP" \
		   -noappend   -no-fragments -no-sparse
	mkfs.ext4 -L exim -d "$OUTDIR"/rootfs.mnt/var/lib/exim4/ "$MAILVAR_LODEVP"
	mkfs.ext4 -L home -d "$OUTDIR"/rootfs.mnt/home/ "$HOME_LODEVP"

	boot_write_bootblock "$DISK_LODEV" "$OUTDIR"/rootfs.mnt
	;;

(*)
	printf '%s\n' "Unknown step $1"
	exit 200
	;;

esac
}
