all:
	install

install:
	mkdir -p /usr/local/share/man/man1
	cp -R backup.sh /usr/local/bin/backup.sh
	cp -R backup_sources.bk /usr/local/etc/backup_sources.bk
	cp -R backup.sh.1 /usr/local/share/man/man1/backup.sh.1
	chmod 755 /usr/local/bin/backup.sh
	chmod 644 /usr/local/etc/backup_sources.bk

uninstall:
	rm -rf /usr/local/bin/backup.sh
	rm -ff /usr/local/etc/backup_sources.bk
	rm -rf /usr/local/share/man/man1/backup.sh.1
