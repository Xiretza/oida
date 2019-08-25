#!#/bin/sh
set -e -u
set -x

cd "$(dirname "$0")"/../../../

. ./test/system/common/mail-deliver-test.fn.sh
. ./test/system/encim/setup.fn.sh

setup

for rcpt_domain in $MAIL_DOMAINS; do
    mail_deliver_test "$MAIL_SERVER_IP" "$DOMAIN" "${CFG_USERNAME}@${rcpt_domain}"
done

ttysh () {
    ./bin/ttysh.expect /run/encim-ttyS0.unix "$@"
}

ttysh

ttysh --no-login 'ls /home/'"$CFG_USERNAME"'/Maildir/cur/*.gpg'

# Ensure one message was delivered for each sent above in the user Maildir
#
# Also make sure the delivered files have a '.gpg' extension since this is
# required for the our FUSE filesystem to decrypt it
#
N_SENT=$(printf '%s' "$MAIL_DOMAINS" | wc -w)
N_DELIVERED=$(ttysh --no-login 'ls /home/'"$CFG_USERNAME"'/Maildir/cur/*.gpg' | tee /dev/stderr | wc -l)
[ "$N_DELIVERED" -eq "$N_SENT" ]
