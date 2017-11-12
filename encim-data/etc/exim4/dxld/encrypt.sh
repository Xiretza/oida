#!/bin/sh

exec gpg --batch --no-tty --passphrase '' --recipient CFG_GPG_ENC_RECIPIENT --encrypt 2>/dev/null
