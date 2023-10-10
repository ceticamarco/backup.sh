all:
	install

install:
	mkdir -p /usr/local/bin /usr/local/etc
	cp -R backup.sh /usr/local/bin/backup.sh
	cp -R sources.bk /usr/local/etc/sources.bk
	cp -R backup.sh.1 /usr/share/man/man1/backup.sh.1
	chmod 755 /usr/local/bin/backup.sh
	chmod 644 /usr/local/etc/sources.bk

uninstall:
	rm -rf /usr/local/bin/backup.sh
	rm -ff /usr/local/etc/sources.bk
	rm -rf /usr/share/man/man1/backup.sh.1
