---
title: backup.sh
section: 1
header: General Commands Manual
footer: Marco Cetica
date: February 27, 2024
---

# NAME
**backup.sh** - POSIX compliant, modular and lightweight backup utility to save and encrypt your files.

# SYNOPSIS
```
Syntax: backup.sh [-b|-e|-h]
options:
-b|--backup  SOURCES DEST PASS  Backup folders from SOURCES file.
-e|--extract ARCHIVE PASS       Extract ARCHIVE using PASS.
-h|--help                       Show this helper.
```

# DESCRIPTION
**backup.sh** is a POSIX compliant, modular and lightweight backup utility to save and encrypt your files. 
This tool is intended to be used on small scale UNIX environment such as VPS, small servers and workstations. 
**backup.sh** uses _rsync_, _tar_ and _gpg_ to copy, compress and encrypt the backup.

# OPTIONS
**backup.sh** supports two options: _backup creation_ and _backup extraction_.
The former requires root permissions, while the latter does not. Let us see them in details:

## Backup creation
To specify the directories to backup, **backup.sh** uses an associative array defined in a text file(called sources file) 
with the following syntax:

```
<LABEL>=<PATH>
```

Where `<LABEL>` is the name of the backup and `<PATH>` is its path. 
For example, if you want to back up _/etc/nginx_ and _/etc/ssh_, add the following entries to the sources file:

```
nginx=/etc/nginx/
ssh=/etc/ssh/
```

**backup.sh** will create two folders inside the backup archive with the following syntax:

```
backup-<LABEL>-<YYYYMMDD>
```

In the previous example, this would be:

```
backup-nginx-<YYYYMMDD>
backup-ssh-<YYYYMMDD>
```

You can add as many entries as you want, just be sure to use the proper syntax. 
In particular, the sources file, _should not_ includes:

    - Spaces between the label and the equal sign;  
    - Empty lines;  
    - Comments.  

You can find a sample sources file at `sources.bk`(or at `/usr/local/etc/sources.bk`).

After having defined the sources file, you can invoke **backup.sh** using the following syntax:
```
$> sudo ./backup.sh --backup <SOURCES_FILE> <DEST> <ENCRYPTION_PASSWORD>
```

Where `<SOURCES_FILE>` is the _sources file_, `<DEST>` is the absolute path of the output of the backup _without trailing slashes_ 
and `<ENCRYPTION_PASSWORD>` is the password to encrypt the compressed archive.

In the previous example, this would be:

```
$> sudo ./backup.sh --backup sources.bk /home/john badpw1234
```

The backup utility will begin to copy the files defined in the sources file:

```
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

You can also use **backup.sh** from a crontab rule:

```
$> sudo crontab -e
30 03 * * 6 EKEY=$(cat /home/john/.ekey) sh -c '/usr/local/bin/backup.sh -b /usr/local/etc/sources.bk /home/john $EKEY' > /dev/null 2>&1
```

This will automatically run **backup.sh** every Saturday morning at 03:30 AM. 
In the example above, the encryption key is stored in a local file(with fixed permissions) to avoid password leaking in crontab logs. 
You can also adopt this practice while using the `--extract` option to avoid password leaking in shell history.

## Backup extraction
**backup.sh** can also extract the encrypted backup archive using the following syntax:

```
$> ./backup.sh --extract <ENCRYPTED_ARCHIVE> <ARCHIVE_PASSWORD>
```

Where `<ENCRYPTED_ARCHIVE>` is the encrypted backup and `<ARCHIVE_PASSWORD>` is the backup password.

For instance:
```
$> ./backup.sh --extract backup-<hostname>-<YYYYMMDD>.tar.gz.enc badpw1234
```

This will create a new folder called `backup.sh.tmp` in your local directory. 
Be sure to rename any directory with that name to avoid collisions. From the previous example, you should have the following directories:

```
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
        --batch --passphrase-fd "$PASSWORD" \
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

# EXAMPLES
Below there are some examples that demonstrate **backup.sh**'s usage.

1. Create a backup of `/etc/ssh`, `/var/www` and `/var/log` inside the `/tmp` directory using a password
stored in `/home/op1/.backup_pw`

The first thing to do is to define the source paths inside a _sources file_:

```
$> cat sources.bk
ssh=/etc/ssh
web_root=/var/www
logs=/var/log
```

After that we can load our encryption key from the specified file inside a environment variable:

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
**backup.sh** was written by Marco Cetica on late 2018.

# BUGS
Submit bug reports online at: <email@marcocetica.com> or open an issue 
on the issue tracker of the GitHub page of this project: https://github.com/ice-bit/backup.sh
