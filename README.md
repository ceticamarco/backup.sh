# backup.sh ![](https://github.com/ceticamarco/backup.sh/actions/workflows/backup.sh.yml/badge.svg)
`backup.sh` is a POSIX compliant, modular and lightweight backup utility to save and encrypt your files.
This tool is intended to be used on small scale UNIX environments such as VPS, personal servers and
workstations. `backup.sh` uses [rsync](https://linux.die.net/man/1/rsync), [tar](https://linux.die.net/man/1/tar)
and [gpg](https://linux.die.net/man/1/gpg) to copy, compress and encrypt the backup. 

`backup.sh` works under the following operating systems: 
- GNU/Linux;
- OpenBSD
- FreeBSD;
- Apple MacOS.

## Installation
`backup.sh` consists in a single source file, to install it you can copy the script wherever you want.
Alternatively, you can install the script, the default sources file and the man file using the following command:
```sh
$> sudo make install
```
This will copy `backup.sh` into `/usr/local/bin/backup.sh`, `sources.bk` into `/usr/local/etc/sources.bk` and
`backup.sh.1` into `/usr/share/man/man1/backup.sh.1`. To uninstall the program along with the sample _sources file_ and the manual page,
you can issue `sudo make uninstall`.

At this point you still need to install the following dependencies:
- `rsync`
- `tar`
- `gpg`

## Usage
To show the available options, you can run `backup.sh --help`, which will print out the following message:
```text
backup.sh - POSIX compliant, modular and lightweight backup utility.

Syntax: ./backup.sh [-b|-e|-h]
options:
-b|--backup  SOURCES DEST PASS  Backup folders from SOURCES file.
-e|--extract ARCHIVE PASS       Extract ARCHIVE using PASS.
-h|--help                       Show this helper.
```

As you can see, `backup.sh` supports two options: **backup creation** and **backup extraction**, the former requires
root permissions, while the latter does not. Let us see them in details.

### Backup creation
To specify the directories to backup, `backup.sh` uses an associative array
defined in a text file(called _sources file_) with the following syntax:

```text
<LABEL>=<PATH>
```

Where `<LABEL>` is the name of the backup and `<PATH>` is its path. For example,
if you want to back up `/etc/nginx` and `/etc/ssh`, add the following entries to the _sources file_:

```text
nginx=/etc/nginx/
ssh=/etc/ssh/
```

`backup.sh` will create two folders inside the backup archive with the following syntax:
```text
backup-<LABEL>-<YYYYMMDD>
```

In the previous example, this would be:
```text
backup-nginx-<YYYYMMDD>
backup-ssh-<YYYYMMDD>
```

You can add as many entries as you want, just be sure to use the proper syntax. In particular,
the _sources file_, **should not** includes:
- Spaces between the label and the equal sign;  
- Empty lines;  
- Comments.

You can find a sample _sources file_ at `sources.bk`(or at `/usr/local/etc/sources.bk`).

After having defined the _sources file_, you can invoke `backup.sh` using the following syntax:
```sh
$> sudo ./backup.sh --backup <SOURCES_FILE> <DEST> <ENCRYPTION_PASSWORD>
```

Where `<SOURCES_FILE>` is the _sources file_, `<DEST>` is the absolute path of the output of the backup 
**without trailing slashes** and `<ENCRYPTION_PASSWORD>` is the password to encrypt the compressed archive.

In the previous example, this would be:
```sh
$> sudo ./backup.sh --backup sources.bk /home/john badpw1234
```

The backup utility will begin to copy the files defined in the _sources file_:
```text
Copying nginx(1/2)
Copying ssh(2/2)
Compressing backup...
Encrypting backup...
File name: /home/marco/backup-<HOSTNAME>-<YYYYMMDD>.tar.gz.enc
File size: 7336400696(6.9G)
File hash: 0e75ca393117f389d9e8edfea7106d98
Elapsed time: 259 seconds.
```

After that, you will find the final backup archive in `/home/john/backup-<HOSTNAME>-<YYYYMMDD>.tar.gz.enc`.

You can also use `backup.sh` from a crontab rule:
```sh
$> sudo crontab -e
30 03 * * 6 EKEY=$(cat /home/john/.ekey) sh -c '/usr/local/bin/backup.sh -b /usr/local/etc/sources.bk /home/john $EKEY' > /dev/null 2>&1

```

This will automatically run `backup.sh` every Saturday morning at 03:30 AM. In the example above, the encryption
key is stored in a local file(with fixed permissions) to avoid password leaking in crontab logs. You can also
adopt this practice while using the `--extract` option to avoid password leaking in shell history.

### Backup extraction
`backup.sh` can also extract the encrypted backup archive using the following syntax:

```sh
$> ./backup.sh --extract <ENCRYPTED_ARCHIVE> <ARCHIVE_PASSWORD>
```

Where `<ENCRYPTED_ARCHIVE>` is the encrypted backup and `<ARCHIVE_PASSWORD>` is the backup password.

For instance:

```sh
$> ./backup.sh --extract backup-<hostname>-<YYYYMMDD>.tar.gz.enc badpw1234
```

This will create a new folder called `backup.sh.tmp` in your local directory. Be sure to rename any directory
with that name to avoid collisions. From the previous example, you should have the following directories:
```text
backup-nginx-<YYYYMMDD>
backup-ssh-<YYYYMMDD>
```


## How does backup.sh work?
**backup.sh** uses _rsync_ to copy the files, _tar_ to compress the backup and _gpg_ to encrypt it. 
By default, rsync is being used with the following parameters:

```
$> rsync -aPhrq --delete
```

That is:

    - a: archive mode: rsync copies files recursively while preserving as much metadata as possible;  
    - P: progress/partial: allows rsync to resume interrupted transfers and to shows progress information;  
    - h: human readable output, rsync shows output numbers in a more readable way;  
    - r: recursive mode: forces rsync to copy directories and their content;  
    - q: quiet mode: reduces the amount of information rsync produces;  
    - delete: delete mode: forces rsync to delete any extraneous files at the destination dir.


After that the backup folder is being encrypted using gpg. By default, it is used with the following parameters:


```
$> gpg -a \
        --symmetric \
        --cipher-algo=AES256 \
        --no-symkey-cache \
        --pinentry-mode=loopback \
        --batch --passphrase "$PASSWORD" \
        --output "$OUTPUT" \
        "$INPUT"
```

This command encrypts the backup using the AES-256 symmetric encryption algorithm with a 256bit key. Here is what each flag do:
 - `--symmetric`: Use symmetric encryption;  
 - `--cipher-algo=AES256`: Use AES256 algorithm;  
 - `--no-symkey-cache`: Do not save password on GPG's cache;  
 - `--pinentry-mode=loopback --batch`: Do not prompt the user;  
 - `--passphrase-fd 3 3<< "$PASSWORD"`: Read password without revealing it on `ps`;  
 - `--output`: Specify output file;  
 - `$INPUT`: Specify input file.

## Unit tests
`backup.sh` provides some unit tests inside the `tests.sh` script. This script generates some dummy files inside the following
directories:
- /var/log
- /var/www
- /etc/nginx
- /etc/ssh

For this reason, this script should **NOT** be used in non-testing environments. To run all tests, issue the following command:
```sh
$> sudo ./tests.sh I_HAVE_READ_THE_HELPER
```

## License
This software is released under GPLv3, you can obtain a copy of this license by cloning this repository or by visiting 
[this page](https://choosealicense.com/licenses/gpl-3.0/).
