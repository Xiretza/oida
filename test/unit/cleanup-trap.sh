#!/bin/sh

set -e

# shellcheck source=lib/oida-cleanup.sh
. ./../../lib/oida-cleanup.sh

cleanup_cmd echo cleanup "$1"

case "$1" in
    INT|TERM)
	kill "-$1" $$
	exit 1
	;;

    EXIT) # exit by reaching end of script
	;;

    EXIT0)
	exit 0
	;;

    EXIT42)
	exit 42
	;;

    ERROR69)
	# this should terminate the script before the "echo cleanup" above
	cleanup_cmd exit 69
	;;

    *)
	exit 123
	;;
esac
