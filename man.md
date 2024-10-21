---
title: backup.sh
section: 1
header: General Commands Manual
footer: Marco Cetica
date: October 21, 2024
---

# NAME
**backup.sh** - POSIX compliant, modular and lightweight backup utility.

# SYNOPSIS
```
Syntax: ./backup.sh [-b|-e|-c|-V|-h]
options:
-b|--backup   SOURCES DEST PASS  Backup folders from SOURCES file.
-e|--extract  ARCHIVE PASS       Extract ARCHIVE using PASS.
-c|--checksum                    Generate/check SHA256 of a backup.
-V|--verbose                     Enable verbose mode.
-h|--help                        Show this helper.

General help with the software: https://github.com/ceticamarco/backup.sh
Report bugs to: Marco Cetica(<email@marcocetica.com>)
```

# DESCRIPTION
**backup.sh** is a POSIX compliant, modular and lightweight backup utility to save and encrypt your files. 
This tool is intended to be used on small scale UNIX environment such as VPS, small servers and workstations. 
**backup.sh** uses _rsync_, _tar_, _sha256sum_ and _gpg_ to copy, compress, verify and encrypt the backup.

# OPTIONS
**backup.sh** supports three options: **backup creation**, **backup extraction** and **checksum** to verify the
integrity of a backup. The first option requires
root permissions, while the second one does not. The checksum option must be used in combination of one of the previous options.

## Backup creation
To specify the directories to back up, `backup.sh` uses an associative array
defined in a text file(called _sources file_) with the following syntax:

```
<LABEL>=<PATH>
```

Where `<LABEL>` is the name of the backup and `<PATH>` is its path. For example,
if you want to back up `/etc/nginx` and `/etc/ssh`, add the following entries to the _sources file_:

```
nginx=/etc/nginx/
ssh=/etc/ssh/
```

`backup.sh` will create two folders inside the backup archive with the following syntax:
```
backup-<LABEL>-<YYYYMMDD>
```

In the previous example, this would be:
```
backup-nginx-<YYYYMMDD>
backup-ssh-<YYYYMMDD>
```

You can add as many entries as you want, just be sure to use the proper syntax. In particular,
the _sources file_, **should not** include:
- Spaces between the label and the equal sign;  
- Empty lines;  
- Comments.

You can find a sample _sources file_ at `sources.bk`(or at `/usr/local/etc/sources.bk`).

After having defined the _sources file_, you can invoke `backup.sh` using the following syntax:
```
$> sudo ./backup.sh --backup <SOURCES_FILE> <DEST> <ENCRYPTION_PASSWORD>
```

Where `<SOURCES_FILE>` is the _sources file_, `<DEST>` is the absolute path of the output of the backup 
**without trailing slashes** and `<ENCRYPTION_PASSWORD>` is the password to encrypt the compressed archive.

In the previous example, this would be:
```
$> sudo ./backup.sh --backup sources.bk /home/john badpw1234
```

You can also tell `backup.sh` to generate a SHA256 file containing the hash of each file using the `-c` option. 
In the previous example, this would be:
```
$> sudo ./backup.sh --checksum --backup sources.bk /home/john badpw1234
```

The backup utility will begin to copy the files defined in the _sources file_:
```
Copying nginx(1/2)
Copying ssh(2/2)
Compressing backup...
Encrypting backup...
File name: /home/john/backup-<HOSTNAME>-<YYYYMMDD>.tar.gz.enc
Checksum file: /home/john/backup-<HOSTNAME>-<YYYYMMDD>.sha256
File size: 7336400696(6.9G)
Elapsed time: 259 seconds.
```

After that, you will find the backup archive and the checksum file in 
`/home/john/backup-<HOSTNAME>-<YYYYMMDD>.tar.gz.enc` and `/home/john/backup-<HOSTNAME>-<YYYYMMDD>.sha256`, respectively.

You can also use `backup.sh` from a crontab rule:
```
$> sudo crontab -e
30 03 * * 6 EKEY=$(cat /home/john/.ekey) bash -c '/usr/local/bin/backup.sh -b /usr/local/etc/sources.bk /home/john $EKEY' > /dev/null 2>&1

```

This will automatically run `backup.sh` every Saturday morning at 03:30 AM. In the example above, the encryption
key is stored in a local file(with fixed permissions) to avoid password leaking in crontab logs. You can also
adopt this practice while using the `--extract` option to avoid password leaking in shell history.

By default `backup.sh` is very quiet, to add some verbosity to the output, be sure to use the `-V`(`--verbose`) option.

## Backup extraction
**backup.sh** can also be used to extract and to verify the encrypted backup.
To do so, use the following commands:

```
$> ./backup.sh --extract <ENCRYPTED_ARCHIVE> <ARCHIVE_PASSWORD>
```

Where `<ENCRYPTED_ARCHIVE>` is the encrypted backup and `<ARCHIVE_PASSWORD>` is the backup password.

For instance:

```
$> ./backup.sh --extract backup-<hostname>-<YYYYMMDD>.tar.gz.enc badpw1234
```

This will create a new folder called `backup.sh.tmp` in your local directory with the following content: 
```
backup-nginx-<YYYYMMDD>
backup-ssh-<YYYYMMDD>
```

**note**: be sure to rename any directory with that name to avoid collisions.


If you also want to verify the integrity of the backup data, use the following commands:
```
$> ./backup.sh --checksum --extract <ENCRYPTED_ARCHIVE> <ARCHIVE_PASSWORD> <CHECKSUM_ABSOLUTE_PATH>
```

For instance:

```
$> ./backup.sh --checksum --extract backup-<hostname>-<YYYYMMDD>.tar.gz.enc badpw1234 backup-<hostname>-<YYYYMMDD>.sha256
```


## How does backup.sh work?
**backup.sh** uses _rsync_ to copy the files, _tar_ to compress the backup, _gpg_ to encrypt it and
_sha256sum_ to verify it.
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

If specified(`--checksum` option), `backup.sh` can also generate the checksum of each file of the backup.
To do so, it uses `sha256sum(1)` to compute the hash of every single file using the SHA256 hashing algorithm.
The checksum file contains nothing but the checksums of the files, no other information about the files stored
on the backup archive is exposed on the unencrypted checksum file. This may be an issue if you want plausible
deniability(see privacy section for more information).


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

## Plausible Deniability
While `backup.sh` provide some pretty strong security against bruteforce attack(assuming a strong passphrase is being used)
it should by no means considered a viable tool against a cryptanalysis investigation. Many of the copying, compressing and
encrypting operations made by `backup.sh` during the backup process can be used to invalidate plausible deniability.
In particular, you should pay attention to the following details:

1. The `--checksum` option generates an **UNENCRYPTED** checksum file containing the _digests_ of **EVERY**
file in your backup archive. If your files are known to your adversary(e.g., a banned book), they may use a rainbow table attack to
determine whether you own a given file, voiding your plausible deniability;  
2. Since `backup.sh` is essentially a set of shell commands, an eavesdropper could monitor the whole backup process to extract
the name of the files or the encryption password.


# EXAMPLES
Below there are some examples that demonstrate **backup.sh**'s usage.

1. Create a backup of `/etc/ssh`, `/var/www` and `/var/log` inside the `/tmp` directory using a password
stored in `/home/op1/.backup_pw`

The first thing to do is to define the source paths inside a _sources file_:

```
$> cat sources.bk
ssh=/etc/ssh/
web_root=/var/www/
singleFile=/home/john/file.txt
logs=/var/log/
```

After that we can load our encryption key from the specified file inside an environment variable:

```
$> ENC_KEY=$(cat /home/op1/.backup_pw)
```

Finally, we can start the backup process with:

```
$> sudo backup.sh --backup sources.bk /tmp $ENC_KEY
```


2. Extract the content of a backup made on 2023-03-14 with the password 'Ax98f!'

To do this, we can simply issue the following command:

```
$> backup.sh --extract backup-af9a8e6bfe15-20230314.tar.gz.enc "Ax98f!"
```


3. Extract the content of a backup made on 2018-04-25 using the password in `/home/john/.pw`

This example is very similar to the previous one, we just need to read the password from the text file:

```
$> backup.sh --extract backup-af9a8e6bfe15-20180425.tar.gz.enc "$(cat /home/john/.pw)"
```

# AUTHORS
**backup.sh** is being developed by Marco Cetica since late 2018.

# BUGS
Submit bug reports at: <email@marcocetica.com> or open an issue 
on the issue tracker of the GitHub page of this project: https://github.com/ice-bit/backup.sh
