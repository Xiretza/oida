#!/bin/sh

exec gpg --batch --no-tty --passphrase '' --recipient dxld@encim.servers.dxld.at --encrypt 2>/dev/null
