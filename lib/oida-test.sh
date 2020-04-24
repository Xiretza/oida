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

if [ "$COMMAND" != "test" ]; then
    echo "$0: Do not run tests directly, they will gobble up your system!">&2
    exit 1
fi

host_destroy () {
    local -; set -u +x
    hostname="$1"; shift
    if ip netns pids "$hostname" >/dev/null 2>&1; then
	    for pid in $(ip netns pids "$hostname"); do
		kill -9 "$pid"
	    done
	    ip netns del "$hostname"
	    ip link del dev "${hostname}-h"
    fi
}

HOST_ADDR=100
HOSTS=
HOSTS_ADDRS=
host_create () {
    local -; set -u -x
    hostname="$1"; shift

    ip netns add "$hostname"
    ip link add  "$hostname"-h type veth peer name "$hostname"-v
    ip link set dev "${hostname}-h" master "$BRIDGE"
    ip link set dev "$hostname"-v netns "$hostname"

    ip -n "$hostname" addr add 1.2.3."$HOST_ADDR"/24 \
       dev "${hostname}-v"

    ip link set dev "${hostname}-h" up
    ip -n "$hostname" link set dev "${hostname}-v" up
    ip -n "$hostname" link set dev lo up

    HOSTS="$hostname $HOSTS"
    HOSTS_ADDRS="$HOSTS_ADDRS
1.2.3.$HOST_ADDR	$hostname"
    HOST_ADDR=$(( HOST_ADDR + 1 ))
}

host_get_next_addr () {
    echo "1.2.3.$HOST_ADDR"
}

dnsmasq_write_hosts () {
    local -; set -u +x
    hostname="$1"; shift

    printf '%s\n' "$HOSTS_ADDRS" > /run/"$hostname".hosts
}

dnsmasq_write_dhcp_hosts () {
    local -; set -u +x
    hostname="$1"; shift

    for q in $QEMUS_DHCP; do
	echo "$q"
    done > /run/"$hostname".dhcp-hosts
}

dnsmasq_reload () {
    local -; set -u +x
    hostname="$1"; shift

    dnsmasq_write_hosts "$hostname"
    dnsmasq_write_dhcp_hosts "$hostname"

    kill -HUP "$(cat /run/"$hostname".pid)"
}

host_start_dnsmasq () {
    local -; set -u -x
    hostname="$1"; shift
    domain="$1"; shift

    dnsmasq_write_hosts "$hostname"
    dnsmasq_write_dhcp_hosts "$hostname"

    ip netns exec "$hostname" \
       dnsmasq -u nobody \
       --resolv-file=/dev/null \
       --dhcp-leasefile=/run/"$hostname".leases \
       --no-hosts \
       --pid-file=/run/"$hostname".pid \
       --addn-hosts=/run/"$hostname".hosts \
       --dhcp-hostsfile=/run/"$hostname".dhcp-hosts \
       --log-facility=- \
       --dhcp-authoritative \
       --dhcp-range=1.2.3.0,static,255.255.255.0 \
       --domain="$domain" \
       --server=/"$domain"/ \
       --expand-hosts \
       "$@"
    #       --log-queries \
}

qemu_destroy () {
    local -; set -u +x
    hostname="$1"; shift

    kill -9 "$(cat /run/"$hostname"-qemu.pid)"
}

QEMUS=
QEMUS_DHCP=
qemu_create () {
    local -; set -u -x
    local hostname disk dnsmasq_hostname tout

    hostname="$1"; shift
    disk="$1"; shift
    dnsmasq_hostname="$1"; shift
    if [ $# -ge 1 ]; then tout="$1"; shift; fi

    local mac
    mac=$(printf 02: ; xxd -l 5 -p < /dev/urandom | sed -r -e 's/(..)/\1:/g' -e 's/:$//')

    ip tuntap add dev "${hostname}-h" mode tap user nobody
    ip link set dev "${hostname}-h" master "$BRIDGE"
    ip link set dev "${hostname}-h" up
    env -- runuser -u nobody -- qemu-system-x86_64 \
	-daemonize \
	-pidfile /run/"$hostname"-qemu.pid \
	-vga none \
	-display none \
	-m 265 \
	-monitor unix:/run/"$hostname"-monitor.unix,server,nowait \
	-serial unix:/run/"$hostname"-ttyS0.unix,server,nowait \
	\
	-net none \
	-net nic,model=e1000,macaddr="$mac" \
	-net tap,ifname="${hostname}-h",script=no,downscript=no \
	\
	-drive file="$disk",format=raw,if=ide

    HOSTS_ADDRS="$HOSTS_ADDRS
1.2.3.$HOST_ADDR	$hostname"
    QEMUS_DHCP="$mac,1.2.3.$HOST_ADDR $QEMUS_DHCP"
    QEMUS="$hostname $QEMUS"

    dnsmasq_reload "$dnsmasq_hostname"

    if [ "$tout" -gt 0 ] && ! ping -q -n -w"$tout" -c1 1.2.3.$HOST_ADDR; then
    	    printf "error: qemu '%s' %s\\n" \
		   "$hostname" "failed to respond after $tout seconds.">&2
    	 exit 1
    fi

    HOST_ADDR=$(( HOST_ADDR + 1 ))
}

bridge_destroy () {
    local -; set -u +x
    bridge="$1"; shift
    ip link del "$bridge" type bridge >/dev/null 2>&1 || true
}

BRIDGE=""
bridge_create () {
    local -; set -u +x
    bridge="$1"; shift

    ip link add "$bridge" type bridge
    ip addr add 1.2.3.254/24 dev "$bridge"
    ip link set dev "$bridge" up

    BRIDGE="$bridge"
}

test_cleanup () {
    local -; set -u +x

    for h in $HOSTS; do
	printf 'Cleaning host %s\n' "$h" >&2
	host_destroy "$h"
    done

    if [ -n "$BRIDGE" ]; then
	    printf 'Cleaning bridge %s\n' "$BRIDGE" >&2
	    bridge_destroy "$BRIDGE"
    fi

    for q in $QEMUS; do
	printf 'Cleaning qemu %s\n' "$q" >&2
	qemu_destroy "$q"
    done
}

cleanup_cmd test_cleanup
