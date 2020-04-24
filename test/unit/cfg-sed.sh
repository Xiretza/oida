#!/bin/bash

set -e

# shellcheck source=lib/oida-cfg.sh
. ./../../lib/oida-cfg.sh

# Hard mode: bash's 'set' prints functions too. We don't use it anymore for
# this reason but still ;)
CFG_FOO () { :; }

sed_cfg
