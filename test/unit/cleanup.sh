#!/bin/sh

set -e

# shellcheck source=lib/cleanup.sh
. ./../../lib/cleanup.sh

trap - EXIT INT TERM

mkdir -p /tmp/encim-tests
cleanup /tmp/encim-tests

mkdir -p /tmp/encim-tests/foo
cleanup /tmp/encim-tests/foo

mkdir -p /tmp/encim-tests/foo/bar
cleanup /tmp/encim-tests/foo/bar

touch \
	/tmp/encim-tests/foo/1 \
	/tmp/encim-tests/foo/2 \
	/tmp/encim-tests/foo/3
cleanup '/tmp/encim-tests/foo/*'

cleanup_cmd echo second
cleanup_cmd echo first

cleanup_do

[ ! -e /tmp/encim-tests ] || exit 1
