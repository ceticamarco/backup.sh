#!/bin/sh -e
# backup.sh is a POSIX compliant, modular and lightweight
# backup utility to save and encrypt your files.
#
# To specify the source directories to backup,
# create a text file with the following syntax:
#
# <LABEL>=<PATH>
#
# for example(filename: 'sources.bk'):
#   nginx=/etc/nginx/
#   ssh=/etc/ssh/
#   logs=/var/log/
#
# After that you can launch the script with(sample usage):
#   sudo ./backup.sh --backup sources.bk /home/john badpw1234
#
# This will create an encrypted tar archive(password: 'badpw1234')
# in '/home/john/backup-<hostname>-<YYYMMDD>.tar.gz.enc' containing
# the following three directories:
#   backup-nginx-<YYYYMMDD>
#   backup-ssh-<YYYYMMDD>
#   backup-logs-<YYYYMMDD>
#
# You can then decrypt it using:
#   ./backup.sh --extract backup-<hostname>-<YYYMMDD>.tar.gz.enc badpw1234
#
# You can read the full guide on https://github.com/ice-bit/backup.sh
# or on the manual page.
# Copyright (c) 2018,2023,2024 Marco Cetica <email@marcocetica.com>
#

checkdeps() {
    # Check if dependencies are installed
    missing_dep=0
    deps="rsync tar gpg"

    for dep in $deps; do
        if ! command -v "$dep" > /dev/null 2>&1; then
            printf "Cannot find '%s', please install it.\n" "$dep"
            missing_dep=1
        fi
    done

    if [ $missing_dep -ne 0 ]; then
        exit 1
    fi
}

checksum() {
    BACKUP_SH_FILENAME="$1"
    BACKUP_SH_OS="$(uname | tr '[:lower:]' '[:upper:]')"

    if [ "$BACKUP_SH_OS" = "LINUX" ]; then
        RES="$(md5sum "$BACKUP_SH_FILENAME" | awk '{print $1}')"
    else
        RES="$(md5 -q "$BACKUP_SH_FILENAME")"
    fi

    echo "$RES"
}

make_backup() {
    BACKUP_SH_SOURCES_PATH="$1"
    BACKUP_SH_OUTPATH="$2"
    BACKUP_SH_PASS="$3"
    BACKUP_SH_COMMAND="rsync -aPhrq --delete"
    BACKUP_SH_DATE="$(date +'%Y%m%d')"
    BACKUP_SH_FOLDER="backup.sh.tmp"
    BACKUP_SH_OUTPUT="$BACKUP_SH_OUTPATH/$BACKUP_SH_FOLDER"
    BACKUP_SH_START_TIME="$(date +%s)"
    BACKUP_SH_FILENAME="$BACKUP_SH_OUTPATH/backup-$(uname -n)-$BACKUP_SH_DATE.tar.gz.enc"

    # Check for root permissions
    if [ "$(id -u)" -ne 0 ]; then
        echo "Run this tool as root!"
        exit 1
    fi

    # Check whether the sources file exists or not
    if [ ! -f "$BACKUP_SH_SOURCES_PATH" ]; then
        echo "$BACKUP_SH_SOURCES_PATH does not exist."
        exit 1
    fi

    # Create temporary directory
    mkdir -p "$BACKUP_SH_OUTPUT"

    # For each item in the array, make a backup
    BACKUP_SH_TOTAL=$(wc -l < "$BACKUP_SH_SOURCES_PATH")
    BACKUP_SH_PROGRESS=1

    while IFS='=' read -r label path; do
        # Define a subdir for each backup entry
        BACKUP_SH_SUBDIR="$BACKUP_SH_OUTPUT/backup-$label-$BACKUP_SH_DATE"
        mkdir -p "$BACKUP_SH_SUBDIR"

        printf "Copying %s(%s/%s)\n" "$label" "$BACKUP_SH_PROGRESS" "$BACKUP_SH_TOTAL"
        $BACKUP_SH_COMMAND "$path" "$BACKUP_SH_SUBDIR"
        BACKUP_SH_PROGRESS=$((BACKUP_SH_PROGRESS+1))
    done < "$BACKUP_SH_SOURCES_PATH"

    # Compress backup directory
    echo "Compressing backup..."
    tar -czf "$BACKUP_SH_OUTPATH/backup.sh.tar.gz" \
        -C "$BACKUP_SH_OUTPATH" "$BACKUP_SH_FOLDER" > /dev/null 2>&1

    # Encrypt backup directory
    echo "Encrypting backup..."
    gpg -a \
        --symmetric \
        --cipher-algo=AES256 \
        --no-symkey-cache \
        --pinentry-mode=loopback \
        --batch --passphrase "$BACKUP_SH_PASS" \
        --output "$BACKUP_SH_FILENAME" \
        "$BACKUP_SH_OUTPATH/backup.sh.tar.gz" > /dev/null 2>&1

    # Remove temporary files
    rm -rf "$BACKUP_SH_OUTPUT"
    rm -rf "$BACKUP_SH_OUTPATH/backup.sh.tar.gz"

    # Print file name, file size, file hash and elapsed time,
    BACKUP_SH_END_TIME="$(date +%s)"
    BACKUP_SH_FILE_SIZE="$(find "$BACKUP_SH_FILENAME" -exec ls -l {} \; |  awk '{print $5}')"
    BACKUP_SH_FILE_SIZE_H="$(find "$BACKUP_SH_FILENAME" -exec ls -lh {} \; | awk '{print $5}')"
    BACKUP_SH_HASH="$(checksum "$BACKUP_SH_FILENAME")"

    echo "File name: $BACKUP_SH_FILENAME"
    echo "File size: $BACKUP_SH_FILE_SIZE($BACKUP_SH_FILE_SIZE_H)"
    echo "File hash: $BACKUP_SH_HASH"
    printf "Elapsed time: %s seconds.\n" "$((BACKUP_SH_END_TIME - BACKUP_SH_START_TIME))"
}

extract_backup() {
    BACKUP_SH_ARCHIVE_PATH="$1"
    BACKUP_SH_ARCHIVE_PW="$2"

    # Decrypt the archive
    gpg -a \
        --decrypt \
        --no-symkey-cache \
        --pinentry-mode=loopback \
        --batch --passphrase "$BACKUP_SH_ARCHIVE_PW" \
        --output backup.sh.tar.gz \
        "$BACKUP_SH_ARCHIVE_PATH"

    # Extract archive
    tar -xzf backup.sh.tar.gz 1> /dev/null 2>&1

    # Remove temporary files
    rm -rf backup.sh.tar.gz
}

helper() {
    CLI_NAME="$1"

    cat <<EOF
backup.sh - POSIX compliant, modular and lightweight backup utility.

Syntax: $CLI_NAME [-b|-e|-h]
options:
-b|--backup  SOURCES DEST PASS  Backup folders from SOURCES file.
-e|--extract ARCHIVE PASS       Extract ARCHIVE using PASS.
-h|--help                       Show this helper.

General help with the software: https://github.com/ice-bit/backup.sh
Report bugs to: Marco Cetica(<email@marcocetica.com>)
EOF
}

main() {
    # Check whether dependecies are installed
    checkdeps

    if [ $# -eq 0 ]; then
        echo "Please, specify an argument."
        echo "For more information, try --help."
        exit 1
    fi

    # Parse CLI arguments
    while [ $# -gt 0 ]; do
        case $1 in
            -b|--backup)
                BACKUP_SH_SOURCES_PATH="$2"
                BACKUP_SH_OUTPATH="$3"
                BACKUP_SH_PASSWORD="$4"

                if [ -z "$BACKUP_SH_SOURCES_PATH" ] || [ -z "$BACKUP_SH_OUTPATH" ] || [ -z "$BACKUP_SH_PASSWORD" ]; then
                    echo "Please, specify a source file, an output path and a password."
                    echo "For more informatio, try --help"
                    exit 1
                fi
                make_backup "$BACKUP_SH_SOURCES_PATH" "$BACKUP_SH_OUTPATH" "$BACKUP_SH_PASSWORD"
                exit 0
                ;;
            -e|--extract)
                BACKUP_SH_ARCHIVE_PATH="$2"
                BACKUP_SH_ARCHIVE_PW="$3"

                if [ -z "$BACKUP_SH_ARCHIVE_PATH" ] || [ -z "$BACKUP_SH_ARCHIVE_PW" ]; then
                    echo "Please, specify an encrypted archive and a password."
                    echo "For more informatio, try --help"
                    exit 1
                fi
                extract_backup "$BACKUP_SH_ARCHIVE_PATH" "$BACKUP_SH_ARCHIVE_PW"
                exit 0
                ;;
            -h|--help)
                helper "$0"
                exit 0
                ;;
            *)
                echo "Unknown option $1."
                echo "For more information, try --help"
                exit 1
                ;;
        esac
    done
}

main "$@"
# vim: ts=4 sw=4 softtabstop=4 expandtab:
