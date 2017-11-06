#!/bin/sh

set +e # otherwise assert_failure wouldn't be reached

# shellcheck source=lib/retry.sh
. ./../../lib/retry.sh

assert_failure () { [ $? -ge 1 ] || exit 1; }
assert_success () { [ $? -ge 1 ] && exit 1; }

retry 1 -- echo runs once
assert_success

retry 3 0 -- sh -c 'echo runs thrice; false'
assert_failure

retry 3 0 -- sh -c 'echo runs once again; true'
assert_success

exit 0
