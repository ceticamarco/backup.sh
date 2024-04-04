#!/usr/bin/env bash
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
#   sudo ./backup.sh --checksum --backup sources.bk /home/john badpw1234
#
# This will create an encrypted tar archive(password: 'badpw1234')
# in '/home/john/backup-<hostname>-<YYYYMMDD>.tar.gz.enc' containing
# the following three directories:
#   backup-nginx-<YYYYMMDD>
#   backup-ssh-<YYYYMMDD>
#   backup-logs-<YYYYMMDD>
#
# as well as a SHA256 file('/home/john/backup-<hostname>-<YYYYMMDD>.sha256')
# containing the file hashes of the backup.
#
# You can then decrypt it using:
#   ./backup.sh --checksum --extract backup-<hostname>-<YYYYMMDD>.tar.gz.enc badpw1234 $PWD/backup-<hostname>-<YYYYMMDD>.sha256
# which will also check the integrity of the backup(optional feature).
#
# You can read the full guide on https://github.com/ceticamarco/backup.sh
# or on the manual page.
# Copyright (c) 2018,2023,2024 Marco Cetica <email@marcocetica.com>
#

set -e

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

# $1: filename
gethash() {
    FILE_NAME="$1"
    OS="$(uname)"

    if [ "$OS" = "Linux" ]; then
        HASH="$(sha256sum "$FILE_NAME" | awk '{print $1}')"
    else
        HASH="$(sha256 -q "$FILE_NAME")"
    fi

    echo "$HASH"
}

# $1: sources.bk file
# $2: output path
# $3: password
# $4: compute sha256(0,1)
make_backup() {
    BACKUP_SH_SOURCES_PATH="$1"
    BACKUP_SH_OUTPATH="$2"
    BACKUP_SH_PASS="$3"
    BACKUP_SH_SHA256="$4"

    BACKUP_SH_COMMAND="rsync -aPhrq --delete"
    BACKUP_SH_DATE="$(date +'%Y%m%d')"
    BACKUP_SH_FOLDER="backup.sh.tmp"
    BACKUP_SH_OUTPUT="$BACKUP_SH_OUTPATH/$BACKUP_SH_FOLDER"
    BACKUP_SH_START_TIME="$(date +%s)"
    BACKUP_SH_FILENAME="$BACKUP_SH_OUTPATH/backup-$(uname -n)-$BACKUP_SH_DATE.tar.gz.enc"
    BACKUP_SH_CHECKSUM_FILE="$BACKUP_SH_OUTPATH/backup-$(uname -n)-$BACKUP_SH_DATE.sha256"

    # Check for root permissions
    if [ "$(id -u)" -ne 0 ]; then
        echo "Run this tool as root!"
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

        # Compute SHA256 of all files of the current directory
        if [ "$BACKUP_SH_SHA256" -eq 1 ]; then
            shopt -s globstar dotglob
            for file in "$path"/**/*; do
                # Skip directories
                [ -d "$file" ] && continue
                gethash "$file" >> "$BACKUP_SH_CHECKSUM_FILE"
            done
            shopt -u globstar dotglob
        fi

        # Copy files
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
        --batch --passphrase-fd 3 3<<< "$BACKUP_SH_PASS" \
        --output "$BACKUP_SH_FILENAME" \
        "$BACKUP_SH_OUTPATH/backup.sh.tar.gz" > /dev/null 2>&1

    # Remove temporary files
    rm -rf "$BACKUP_SH_OUTPUT"
    rm -rf "$BACKUP_SH_OUTPATH/backup.sh.tar.gz"

    # Print file name, file size, file hash and elapsed time,
    BACKUP_SH_END_TIME="$(date +%s)"
    BACKUP_SH_FILE_SIZE="$(find "$BACKUP_SH_FILENAME" -exec ls -l {} \; |  awk '{print $5}')"
    BACKUP_SH_FILE_SIZE_H="$(find "$BACKUP_SH_FILENAME" -exec ls -lh {} \; | awk '{print $5}')"

    echo "File name: $BACKUP_SH_FILENAME"
    [ "$BACKUP_SH_SHA256" -eq 1 ] && { echo "Checksum file: $BACKUP_SH_CHECKSUM_FILE"; }
    echo "File size: $BACKUP_SH_FILE_SIZE($BACKUP_SH_FILE_SIZE_H)"
    printf "Elapsed time: %s seconds.\n" "$((BACKUP_SH_END_TIME - BACKUP_SH_START_TIME))"
}

# $1: archive file
# $2: archive password
# $3: sha256 file(optional)
extract_backup() {
    BACKUP_SH_ARCHIVE_PATH="$1"
    BACKUP_SH_ARCHIVE_PW="$2"
    BACKUP_SH_SHA256_FILE="$3"

    # Decrypt the archive
    gpg -a \
        --quiet \
        --decrypt \
        --no-symkey-cache \
        --pinentry-mode=loopback \
        --batch --passphrase-fd 3 3<<< "$BACKUP_SH_ARCHIVE_PW" \
        --output backup.sh.tar.gz \
        "$BACKUP_SH_ARCHIVE_PATH"

    # Extract archive
    tar -xzf backup.sh.tar.gz 1> /dev/null 2>&1

    # If specified, use SHA256 file to compute checksum of files
    if [ -n "$BACKUP_SH_SHA256_FILE" ]; then
        shopt -s globstar dotglob
        for file in "backup.sh.tmp"/**/*; do
            # Skip directories
            [ -d "$file" ] && continue;
            # Compute sha256 for current file
            SHA256="$(gethash "$file")"
            # Check if checksum file contains hash
            if ! grep -wq "$SHA256" "$BACKUP_SH_SHA256_FILE"; then
                printf "[FATAL] - integrity error for '%s'.\n" "$file"
                rm -rf backup.sh.tar.gz backup.sh.tmp
                exit 1
            fi
        done
        shopt -u globstar dotglob
    fi

    rm -rf backup.sh.tar.gz
}

helper() {
    CLI_NAME="$1"

    cat <<EOF
backup.sh - POSIX compliant, modular and lightweight backup utility.

Syntax: $CLI_NAME [-b|-c|-e|-h]
options:
-b|--backup   SOURCES DEST PASS  Backup folders from SOURCES file.
-c|--checksum                    Generate/check SHA256 of a backup.
-e|--extract  ARCHIVE PASS       Extract ARCHIVE using PASS.
-h|--help                        Show this helper.

General help with the software: https://github.com/ceticamarco/backup.sh
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

    CHECKSUM_FLAG=0
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
                
                if [ "$CHECKSUM_FLAG" -eq 1 ]; then
                    [ -e "$BACKUP_SH_SOURCES_PATH" ] || { echo "Sources file does not exist"; exit 1; }
                    make_backup "$BACKUP_SH_SOURCES_PATH" "$BACKUP_SH_OUTPATH" "$BACKUP_SH_PASSWORD" 1
                else
                    make_backup "$BACKUP_SH_SOURCES_PATH" "$BACKUP_SH_OUTPATH" "$BACKUP_SH_PASSWORD" 0
                fi

                exit 0
                ;;
            -c|--checksum)
                [ $# -eq 1 ] && { echo "Use this option with '--backup' or '--extract'"; exit 1; }
                CHECKSUM_FLAG=1
                shift 1
                ;;
            -e|--extract)
                BACKUP_SH_ARCHIVE_FILE="$2"
                BACKUP_SH_ARCHIVE_PW="$3"
                BACKUP_SH_SHA256_FILE="$4"

                if [ "$CHECKSUM_FLAG" -eq 1 ]; then
                    if [ -z "$BACKUP_SH_ARCHIVE_FILE" ] || [ -z "$BACKUP_SH_ARCHIVE_PW" ] || [ -z "$BACKUP_SH_SHA256_FILE" ]; then
                        echo "Please, specify an encrypted archive, a password and a SHA256 file."
                        echo "For more informatio, try --help"
                        exit 1
                    fi
                else
                    if [ -z "$BACKUP_SH_ARCHIVE_FILE" ] || [ -z "$BACKUP_SH_ARCHIVE_PW" ]; then
                        echo "Please, specify an encrypted archive and a password."
                        echo "For more informatio, try --help"
                        exit 1
                    fi
                fi

                if [ "$CHECKSUM_FLAG" -eq 1 ]; then
                    [ -e "$BACKUP_SH_SHA256_FILE" ] || { echo "Checksum file does not exist"; exit 1; }
                    [ -e "$BACKUP_SH_ARCHIVE_FILE" ] || { echo "Backup file does not exist"; exit 1; }
                    extract_backup "$BACKUP_SH_ARCHIVE_FILE" "$BACKUP_SH_ARCHIVE_PW" "$BACKUP_SH_SHA256_FILE"
                else
                    extract_backup "$BACKUP_SH_ARCHIVE_FILE" "$BACKUP_SH_ARCHIVE_PW"
                fi

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
