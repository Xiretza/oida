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

set -e -u

source oida-cfg.sh
source oida-image.sh
source oida-loopback.sh
source oida-overlay.sh

cfg CFG_DEBIAN_RELEASE:-stretch
cfg CFG_USERNAME:-dxld
cfg CFG_HOSTNAME:-encim
cfg CFG_FQDN:-encim.servers.dxld.at
cfg CFG_EXIM_OTHER_HOSTNAMES:-"$CFG_FQDN : dxld.at : darkboxed.org"
cfg CFG_GPG_ENC_RECIPIENT:-dxld@encim.servers.dxld.at
cfg CFG_ROOT_PASSWORD:-root

# Device and partition number to resize on early bootup
cfg CFG_PART_BOOT_RESIZE_DISK:-/dev/sda
cfg CFG_PART_BOOT_RESIZE_NUMBER:-7

DATADIR="$(realpath "$(dirname "$BASH_SOURCE")")"/encim-data
export DATADIR
readonly DATADIR

TARGET=$OUTDIR/rootfs
cleanup "$TARGET"
mkdir -p "$TARGET" #< just a mountpoint



#				   bootstrap
if ! [ -e "$OUTDIR"/rootfs.bootstrap.done ]; then
	debootstrap \
		--merged-usr \
		--include=linux-image-amd64,initramfs-tools \
		"$CFG_DEBIAN_RELEASE" "$OUTDIR"/rootfs.bootstrap

	touch "$OUTDIR"/rootfs.bootstrap.done
fi

overlay_mount "$OUTDIR"/rootfs.bootstrap "$TARGET"

ns_open FANCY_ROOTFS_NS mnt
unshare mnt
ns_open JUST_ROOTFS_NS mnt
builtin setns "${FANCY_ROOTFS_NS[@]}"
unset FANCY_ROOTFS_NS
# ^ I do it this weird, complicated way to have the parent namespace, which is
# represented on the host in /run/encim, be more useful for debugging.

mount -t proc     proc       "$TARGET"/proc
mount -t sysfs    sysfs      "$TARGET"/sys
mount -t devtmpfs devtmpfs   "$TARGET"/dev
mount -t devpts   devpts     "$TARGET"/dev/pts
mount -t tmpfs    tmpfs      "$TARGET"/run
mount -t tmpfs    tmpfs      "$TARGET"/tmp
mount -o bind,ro  "$DATADIR" "$TARGET"/srv



# 				     config
cp -dR --preserve=mode,timestamps --remove-destination \
   "$DATADIR"/boot \
   "$DATADIR"/etc \
   "$DATADIR"/home \
   "$DATADIR"/usr \
   "$DATADIR"/var \
   \
   "$TARGET"

sed_cfg -i \
	"$TARGET"/etc/systemd/system/resize-home-fs.service \
	"$TARGET"/etc/exim4/update-exim4.conf.conf \
	"$TARGET"/etc/exim4/dxld/encrypt.sh \
	"$TARGET"/etc/mailname \
	"$TARGET"/etc/hostname

mv "$TARGET"/home/user/ \
   "$TARGET"/home/"$CFG_USERNAME"

chown -R 1000:1000 \
      "$TARGET"/home/"$CFG_USERNAME"

echo "root:$CFG_ROOT_PASSWORD" \
	| chpasswd -c SHA512 -R "$TARGET"

useradd -M -U \
	-u 1000 \
	-s /bin/bash \
	-R "$TARGET" \
	"$CFG_USERNAME"


(
#### let's go!
builtin chroot "$TARGET"; cd /


# 				 debconf update
update-initramfs -u
sed_cfg /srv/debconf-db | debconf-set-selections



# 				install packages
apt-get update
DEBIAN_FRONTEND=noninteractive \
	       apt-get install -y -q \
	       grub-pc-bin \
	       systemd-sysv \
	       cloud-guest-utils \
	       locales \
	       dhcpcd5 \
	       openssh-server \
	       exim4-daemon-heavy \
	       exim4-config \
	       util-linux



# 			       cleanup apt cache
rm /var/cache/apt/archives/*.deb



# 			   bootloader (rootfs stage)
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
)



builtin setns "${JUST_ROOTFS_NS[@]}"

# 				      disk
image_create "disk" 1500M DISK_IMAGE
sfdisk "$DISK_IMAGE" <<-EOF
		1M, 512M   , L, *
		  , 512M   , L,
		  ,        , E,
		  , 32M    , L,
		  , 32M    , L,
		  , 128M   , L,
	EOF

loopback_create "$DISK_IMAGE" DISK_LODEV

ROOTFS_LODEVP="${DISK_LODEV}p1"
MAILVAR_LODEVP="${DISK_LODEV}p5"
HOME_LODEVP="${DISK_LODEV}p7"

mkfs.ext4 -L exim -d "$TARGET"/var/lib/exim4/ "$MAILVAR_LODEVP"
mkfs.ext4 -L home -d "$TARGET"/home/ "$HOME_LODEVP"

rm -r "$TARGET"/var/lib/exim4/
rm -r "$TARGET"/home/

# see debian bug #869771 about the last two options
mksquashfs "$TARGET" "$ROOTFS_LODEVP" \
	   $(tty -s || printf '%s' -no-progress) -noappend \
	   -no-fragments -no-sparse



# 			bootloader (block device stage)
(
	# Mount the newly created squashfs to workaround this error:
	#
	# grub-bios-setup: error: failed to get canonical path of `overlay'.
	builtin unshare mnt
	umount -R "$TARGET"
	mount "$ROOTFS_LODEVP" "$TARGET"
	mount -t devtmpfs devtmpfs "$TARGET"/dev
	mount -t proc     proc     "$TARGET"/proc
	mount -t sysfs    sysfs    "$TARGET"/sys

	builtin chroot "$TARGET"

	/usr/lib/grub/i386-pc/grub-bios-setup \
		--directory=/boot/grub/i386-pc \
		"$DISK_LODEV"

)
