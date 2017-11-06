#!#/bin/sh
set -e


set -u

# shellcheck source=lib/cleanup.sh
. "$(dirname "$0")"/../../lib/cleanup.sh

# shellcheck source=lib/retry.sh
. "$(dirname "$0")"/../../lib/retry.sh

# shellcheck source=lib/test.sh
. "$(dirname "$0")"/../../lib/test.sh

IMAGE=

# Usage: setup QEMU_TIMEOUT [ENCIM_IP= [TESTER_IP= [DNSMASQ_IP=]]]
setup () {
    local -; set -u +x

    local tout encim_ip_var tester_ip_var dnsmasq_ip_var
    tout="$1"; shift
    encim_ip_var=
    tester_ip_var=
    dnsmasq_ip_var=
    if [ $# -ge 1 ]; then encim_ip_var="$1"; shift; fi
    if [ $# -ge 1 ]; then tester_ip_var="$1"; shift; fi
    if [ $# -ge 1 ]; then dnsmasq_ip_var="$1"; shift; fi


    bridge_create "encim-br"

    IMAGE=$(mktemp --tmpdir encim-XXXXXXXX.image)
    cleanup "$IMAGE"
    cp "$ENCIM_IMAGE" "$IMAGE"
    chown nobody "$IMAGE"

    if [ -n "$dnsmasq_ip_var" ]; then
	    eval "$dnsmasq_ip_var=\$(host_get_next_addr)"
    fi
    host_create "dnsmasq"
    host_start_dnsmasq "dnsmasq" \
	--mx-host=darkboxed.org,encim.servers.dxld.at \
	--mx-host=dxld.at,encim.servers.dxld.at \
	--mx-host=tester.servers.dxld.at,tester.servers.dxld.at

    if [ -n "$tester_ip_var" ]; then
	    eval "$tester_ip_var=\$(host_get_next_addr)"
    fi
    host_create "tester"

    if [ -n "$encim_ip_var" ]; then
	    eval "$encim_ip_var=\$(host_get_next_addr)"
    fi
    qemu_create "encim" "$IMAGE" "dnsmasq" "$tout"
}
