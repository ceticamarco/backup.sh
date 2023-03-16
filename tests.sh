#!/bin/bash
# Unit tests for backup.sh
# This tool is NOT intended to be used outside
# of a testing environment, please use at your own risk.
# By Marco Cetica 2023 (<email@marcocetica.com>)
#

set -e

helper() {
    cat <<EOF
backup.sh unit testing suite.
Do **NOT** use this tool outside of a testing environment.

This tool creates a lot of dummy files to emulate a real production
environment. Any file inside the following directories will be overwritten:
    - /var/log
    - /var/www
    - /etc/nginx
    - /etc/ssh

Please, use at your own risk.
To acknowledge that, run again this tool with 'I_HAVE_READ_THE_HELPER' as a parameter.
EOF
}

create_files() {
    mkdir -p /etc/{ssh,nginx}
    mkdir -p /var/{www,log}

    touch /etc/ssh/{ssh_config,sshd_config,moduli,ssh_host_dsa_key}
    touch /etc/nginx/{nginx.conf,fastcgi.conf,mime.types}
    touch /var/www/{index.html,style.css,logic.js}
    touch /var/log/{access.log,error.log,lastlog,messages}

    for file in ssh_config sshd_config moduli ssh_host_dsa_key ; do
        head -c 1M </dev/random > /etc/ssh/$file
    done

    for file in index.html style.css logic.js ; do
        head -c 1M </dev/random > /var/www/$file
    done

    for file in nginx.conf fastcgi.conf mime.types ; do
        head -c 1M </dev/random > /etc/nginx/$file
    done

    for file in access.log error.log lastlog messages ; do
        head -c 1M </dev/random > /var/log/$file
    done
}

execute_backup() {
    ./backup.sh -b sources.bk "$PWD" badpw
}

extract_backup() {
    ./backup.sh -e "$PWD"/backup-*-*.tar.gz.enc badpw
}

test_backup() {
    for dir in "$PWD/backup.sh.tmp/"backup-*-* ; do
        if [ ! -d "$dir" ]; then
            echo "Can't find '$dir' backup!"
            exit 1
        else
            echo "Found '$dir'"
        fi
    done
}


if [ $# -eq 0 ]; then
    helper
    exit 1
fi


if [ "$1" = "I_HAVE_READ_THE_HELPER" ]; then
    if [ "$(id -u)" -ne 0 ]; then
        echo "Run this tool as root"
        exit 1
    fi

    create_files
    execute_backup
    extract_backup
    test_backup
fi
