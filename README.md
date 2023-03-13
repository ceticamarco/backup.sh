# backup.sh
`backup.sh` is a POSIX compliant, modular and lightweight backup utility to save and encrypt your files.
This tool is intended to be used on small scale UNIX environment such as VPS, small servers and 
workstations. `backup.sh` uses [rsync](https://linux.die.net/man/1/rsync), [tar](https://linux.die.net/man/1/tar)
and [openssl](https://linux.die.net/man/1/openssl) to copy, compress and encrypt the backup. 

## Installation
`backup.sh` consists in a single source file, to install it you can copy the script wherever you want.
Alternatively, you can install the script, the default sources file and the man file using the following command:
```sh
$> sudo make install
```
This will copy `backup.sh` into `/usr/local/bin/backup.sh`, `backup_sources.bk` into `/usr/local/etc/backup_sources.bk` and
`backup.sh.1` into `/usr/local/share/man/man1`.

At this point you still need to install the dependencies:
- `rsync`
- `tar`
- `openssl`

## Usage
To show the available options, you can run `backup.sh --help`, which will print out the following message:
```text
backup.sh - POSIX compliant, modular and lightweight backup utility.

Syntax: ./backup.sh [-b|-e|-h]
options:
-b|--backup  SOURCES USER PASS  Backup folders from SOURCES file.
-e|--extract ARCHIVE PASS       Extract ARCHIVE using PASS.
-h|--help                       Show this helper.
```

As you can see, `backup.sh` supports two options: **backup creation** and **archive extraction**, the former requires
root permissions, while the latter does not. Let us see them in details.

### Backup creation
To specify the directories to backup, `backup.sh` uses an associative array called
defined in a text file(called _sources file_) with the following syntax:

```text
<LABEL>=<PATH>
```

Where `<LABEL>` is the name of the backup and `<PATH>` is its path. For example,
if you want you back up `/etc/nginx` and `/etc/ssh`, add the following entries to the _sources file_:

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

You can find a sample _sources file_ at `backup_sources.bk`(or at `/usr/local/etc/backup_sources.bk`).

After having defined the _sources file_, you can invoke `backup.sh` using the following syntax:
```sh
$> sudo ./backup.sh --backup <SOURCES_FILE> <USER> <ENCRYPTION_PASSWORD>
```

Where `<SOURCES_FILE>` is the _sources file_, `<USER>` is the home directory where you want the final backup
and `<ENCRYPTION_PASSWORD>` is the password to encrypt the compressed archive.

In the previous example, this would be:
```sh
$> sudo ./backup.sh --backup sources.bk john badpw1234
```

The backup utility will begin to copy the files defined in the _sources file_:
```text
Copying nginx(1/2)
Copying ssh(2/2)
Compressing and encrypting backup...
Elapsed time: 10 seconds.
```

After that, you will find the final backup archive in `/home/john/backup-<HOSTNAME>-<YYYMMDD>.tar.gz.enc`.

You can also use `backup.sh` from a crontab rule:
```sh
$> sudo crontab -e
30 03 * * 6 EKEY=$(cat /home/john/.ekey) /usr/local/bin/backup.sh -b /usr/local/etc/sources.bk john $EKEY

```

This will automatically run `backup.sh` every Saturday morning at 03:30 AM. In the example above, the encryption
key is stored in a local file(with fixed permissions) to avoid password leaking in crontab logs. You can also
adopt this practice while using the `--extract` option to avoid password leaking in shell history.

### Archive extraction
`backup.sh` can also extract the encrypted backup archive using the following syntax:

```sh
$> ./backup.sh --extract <ENCRYPTED_ARCHIVE> <ARCHIVE_PASSWORD>
```

where `<ENCRYPTED_ARCHIVE>` is the encrypted backup and `<ARCHIVE_PASSWORD>` is the backup password.

For instance:

```sh
$> ./backup.sh -extract backup-<hostname>-<YYYMMDD>.tar.gz.enc badpw1234
```

This will create a new folder called `backup.sh.tmp` in your local directory. Be sure to rename any directory
with that name to avoid collisions. From the previous example, you should have the following directories:
```text
backup-nginx-<YYYYMMDD>
backup-ssh-<YYYYMMDD>
```


## How does `backup.sh` work
TODO: explain backend(rsync) parameters.
### Backup flow
Graph with:
1. loop through sources;
2. Copy each source in tmp dir;
3. Compress the archive and encrypt it.
### Encryption
TODO: show `file` output of the backup

## Unit tests
## License
