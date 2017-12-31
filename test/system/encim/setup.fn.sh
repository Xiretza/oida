. ./lib/image.sh
. ./lib/cleanup.sh
. ./lib/test.sh

setup () {
    TIMEOUT=120
    DOMAIN='servers.dxld.at'
    MAIL_DOMAINS='encim.servers.dxld.at dxld.at darkboxed.org'

    CFG_USERNAME=${CFG_USERNAME:-'dxld'}

    DISK_IMAGE="$WORKDIR"/90-disk.image

    bridge_create "encim-br"

    host_create "dnsmasq"
    host_start_dnsmasq "dnsmasq" "$DOMAIN" \
		       --mx-host=darkboxed.org,encim."$DOMAIN" \
		       --mx-host=dxld.at,encim."$DOMAIN" \
		       --mx-host=tester."$DOMAIN",tester."$DOMAIN"

    host_create "tester"

    eval "MAIL_SERVER_IP=\$(host_get_next_addr)"
    image_copy_tmp "$DISK_IMAGE" DISK_IMAGE_RW nobody

    qemu_create "encim" "$DISK_IMAGE_RW" "dnsmasq" "$TIMEOUT"
}
