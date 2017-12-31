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

# Usage: cfg VAR:-DEFAULT
cfg () {
    eval "unset _${1%%:*} ${1%%:*}; _${1%%:*}=\${$1}"
    eval "readonly ${1%%:*}=\"\$_${1%%:*}\"; unset _${1%%:*}"
}

# Usage: replace_cfg FILE...
sed_cfg () {
    exec 3<&0
    set | grep ^CFG_ | (
	while read -r c; do
	    eval "v=\$${c%%=*}"
	    set -- -e "s/${c%%=*}/$v/" "$@"
	done
	sed "$@" <&3
    )
    exec 3<&-
}

cfg CFG_DEBIAN_RELEASE:-stretch
cfg CFG_HOSTNAME:-mail
cfg CFG_FQDN:-mail.parabox.it-syndikat.org
cfg CFG_EXIM_OTHER_HOSTNAMES:-"$CFG_FQDN : it-syndikat.org"
cfg CFG_ROOT_PASSWORD:-root

export DATADIR
readonly DATADIR="$TOPDIR"/its-mail-data

imports () {
	printf '%s\n' \
       	       cleanup.sh \
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
		20-config=in_target,overlay \
		21-config-update=in_target_chroot \
		\
		30-packages=in_target_chroot,overlay \
		\
		40-cleanup=in_target_chroot,overlay\
		\
		50-bootloader=in_target_chroot,overlay \
		\
		90-disk=in_target_overlay
}


install_deps () {
    apt-get install \
	    debootstrap \
	    squashfs-tools \
	    e2fsprogs \
	    dnsmasq \
	    qemu-system \
	    swaks \
	    socat
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
			"$CFG_DEBIAN_RELEASE" "$OUTDIR"/"$name"
	fi

	in_target_mount -t proc     proc       /proc
	in_target_mount -t sysfs    sysfs      /sys
	in_target_mount -t devtmpfs devtmpfs   /dev
	in_target_mount -t devpts   devpts     /dev/pts
	in_target_mount -t tmpfs    tmpfs      /run
	in_target_mount -t tmpfs    tmpfs      /tmp
	in_target_mount -o bind,ro  "$DATADIR" /srv
	;;

(config)
	cp -dR --preserve=mode,timestamps --remove-destination \
	   "$DATADIR"/boot \
	   "$DATADIR"/etc \
	   "$DATADIR"/usr \
	   \
	   "$OUTDIR"/rootfs.mnt

	sed_cfg -i \
		"$OUTDIR"/rootfs.mnt/etc/mailname \
		"$OUTDIR"/rootfs.mnt/etc/hostname

	echo "root:$CFG_ROOT_PASSWORD" \
		| chpasswd -c SHA512 -R "$OUTDIR"/rootfs.mnt
	;;

(config-update)
	update-initramfs -u
	cat /srv/debconf-db \
		| sed_cfg - \
		| debconf-set-selections
	;;

(packages)
	apt-get update
	DEBIAN_FRONTEND=noninteractive \
		apt-get install -y -q \
			grub-pc-bin \
			util-linux \
			less \
			debconf-utils \
			systemd-sysv \
			cloud-guest-utils \
			locales \
			dhcpcd5 \
			openssh-server \
			exim4-daemon-heavy \
			exim4-config \
			dovecot-imapd
	;;


(cleanup)
	rm /var/cache/apt/archives/*.deb
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
		   $(tty -s || printf '%s' -no-progress) -noappend \
		   -no-fragments -no-sparse
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
