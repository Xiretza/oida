. oida-retry.sh
. oida-cleanup.sh
. oida-test.sh

# Usage: mail_deliver_test MAIL_SERVER DOMAIN RECIPIENT
#
# Send a test mail addressed for $RECIPIENT by connecting to
# $MAIL_SERVER. $DOMAIN should be the domain for the HELO SMTP command and From
# header.
mail_deliver_test () {
    local mail_server domain recipient

    mail_server="$1"; shift
    domain="$1"; shift
    recipient="$1"; shift

    retry 10 -- ip netns exec tester  \
	  swaks \
	  --server "$mail_server" \
	  --helo "tester.${domain}" \
	  --from root@"tester.${domain}" \
	  --to "$recipient" \
	  --timeout 5
}
