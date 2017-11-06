#!/bin/sh

if [ -z "$ENCIM_TEST" ]; then
    echo "$0: Do not run tests directly, they will gobble up your system!"
    exit 1
fi
