#!#/bin/sh
set -e -u

# shellcheck source=test/system/_common_test-system-check.sh
. "$(dirname "$0")"/_common_test-system-check.sh

# shellcheck source=test/system/_common_client-server-setup.sh
. "$(dirname "$0")"/_common_client-server-setup.sh

setup 120 encim_ip

i=0
# $encim_ip is assigned by setup above
# shellcheck disable=SC2154
retry 10 -- ip netns exec tester swaks \
      --server "$encim_ip" \
      --helo tester.servers.dxld.at \
      --from root@tester.servers.dxld.at \
      --to dxld@darkboxed.org \
      --timeout 5

TTYSH="$(dirname "$0")"/../../ttysh.sh

"$TTYSH" "encim" begin

# Ensure _one_ message was delivered in the user Maildir
"$TTYSH" "encim" cmd  test -f '/home/*/Maildir/cur/*'

# Make sure the delivered file has a '.gpg' extension since this is required for
# the our FUSE filesystem to decrypt it
"$TTYSH" "encim" cmd  ls -l '/home/*/Maildir/cur/*' '|' grep '\.gpg$'
