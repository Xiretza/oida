#!#/bin/sh
set -e -u

# shellcheck source=test/system/_common_test-system-check.sh
. "$(dirname "$0")"/_common_test-system-check.sh

# shellcheck source=test/system/_common_client-server-setup.sh
. "$(dirname "$0")"/_common_client-server-setup.sh

setup 0 encim_ip

socat STDIO,raw,echo=0,escape=0x1d UNIX-CONNECT:/run/encim-ttyS0.unix
