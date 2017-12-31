#!#/bin/sh
set -e -u

cd "$(dirname "$0")"/../../

pwd

. "$1"

setup

printf '%s\n' "$ socat STDIO,raw,echo=0,escape=0x1d UNIX-CONNECT:/run/*-ttyS0.unix"

bash
