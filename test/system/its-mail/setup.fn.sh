. ./lib/image.sh
. ./lib/cleanup.sh
. ./lib/test.sh

setup () {
    TIMEOUT=120
    DOMAIN=parabox.it-syndikat.org
    MAIL_DOMAIN=it-syndikat.org

    DISK_IMAGE="$WORKDIR"/90-disk.image

    bridge_create "its-mail-br"

    host_create "dnsmasq"
    host_start_dnsmasq "dnsmasq" "$DOMAIN" \
		--mx-host=it-syndikat.org,mail.parabox.it-syndikat.org \
		--mx-host=tester.parabox.it-syndikat.org,tester.parabox.it-syndikat.org

    host_create "tester"

    eval "MAIL_SERVER_IP=\$(host_get_next_addr)"
    image_copy_tmp "$DISK_IMAGE" IMAGE nobody

    qemu_create "mail" "$IMAGE" "dnsmasq" "$TIMEOUT"
}
