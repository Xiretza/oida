EncIM
=====

A personal mail server setup using Exim4 with data at rest encryption based on
`gpg`.

Outline
-------

Incoming mail is queued in a small read-write ext4 partition. On delivery to the
Maildir the entire mail (including headers) is encrypted to a pre-determined
pubkey using gpg. Additionally every hour the mail server is stopped temporarily
and the queue partition is shredded to ensure the queue does not leak
information in case of compromise[1](#fn1).

We assume mail is retrived using `rsync` since running an IMAP server is not
worth the effort for personal use but since IMAP doesn't care about the content
of the mail this should be possible still.

A FUSE filesystem for transparently decrypting files in a Maildir is currently
in development and will be published soon^{TM}.

<a name="fn1">[1]:</a> Currently we use `shred(1)` for shredding the queue
  partition which only really works if the disk is a plain HDD and not some
  flash or SAN based thing. Encrypting the disk would be better but without a
  non-disk location to store the key we might as well not bother. TPMs might
  well be something to look into in the future though.

Building and testing a disk image
---------------------------------

The following command will spit out a disk image in
`/srv/encim-workdir/90-disk.image`:

```
$ sudo ./build-image.sh /srv/encim-workdir encim.sh
```

To test the disk image actually works run one (or all) of the tests:

```
$ sudo env ENCIM_IMAGE=/srv/encim-workdir/90-disk.image ./test.sh test/system/mail-delivery.sh
```

You can use `test/system/manual.sh` in the command above instead to boot the
same test setup but get a shell.

Dependencies
------------

On Debian the following command will install all necessary dependencies:

```
apt-get install git debootstrap squashfs-tools qemu-system swaks dnsmasq expect socat 
```
