

.PHONY: all clean install deb-package

all: 

clean:
	find . -type f -name '*~' -delete 
	find . -type f -name "tmp.*" -delete
	find . -maxdepth 1 -type f -name 'letsencrypt-dns-conoha_*_all.deb' -delete
	rm -rf build

install:
	if [ ! -d $(PREFIX)/var/lib/letsencrypt/letsencrypt-dns-conoha ]; then mkdir -p $(PREFIX)/var/lib/letsencrypt/letsencrypt-dns-conoha ; fi
	install --target-directory=$(PREFIX)/var/lib/letsencrypt/letsencrypt-dns-conoha create_conoha_dns_record.sh delete_conoha_dns_record.sh
	if [ ! -d $(PREFIX)/usr/sbin ]; then mkdir -p $(PREFIX)/usr/sbin ; fi
	install --target-directory=$(PREFIX)/usr/sbin create-conoha_id
	if [ ! -d $(PREFIX)/usr/libexec/conoha-acme-challenge ]; then mkdir -p $(PREFIX)/usr/libexec/conoha-acme-challenge ; fi
	install --target-directory=$(PREFIX)/usr/libexec/conoha-acme-challenge conoha-acme-challenge.sh

deb-package:
	if [ ! -d build ]; then mkdir -p build ; fi;
	PREFIX=$(shell realpath build) make install
	if [ ! -d build/DEBIAN ] ; then mkdir build/DEBIAN ; fi
	cp control build/DEBIAN
	fakeroot dpkg-deb --build build .
