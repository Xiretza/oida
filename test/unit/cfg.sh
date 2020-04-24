#!/bin/bash

set -e

# shellcheck source=lib/oida-cfg.sh
. ./../../lib/oida-cfg.sh

is_exported () { local var="$1"; [[ "${!var@a}" == *x* ]]; }

cfg CFG_FOO foo

eval "$1"
