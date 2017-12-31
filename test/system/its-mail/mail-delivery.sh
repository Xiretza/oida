#!#/bin/sh
set -e -u
set -x

cd "$(dirname "$0")"/../../../

. ./test/system/common/mail-deliver-test.fn.sh
. ./test/system/its-mail/setup.fn.sh

setup

ttysh () {
    ./bin/ttysh.expect /run/mail-ttyS0.unix "$@"
}

ttysh

ttysh --no-login 'useradd --create-home testuser'
ttysh --no-login 'echo testuser:testpassword | chpasswd -c SHA512'

mail_deliver_test "$MAIL_SERVER_IP" "$DOMAIN" "testuser@$MAIL_DOMAIN"

# Ensure one message was delivered in the user Maildir
ttysh --no-login 'test -f /home/testuser/Maildir/cur/*.gpg'

bash
