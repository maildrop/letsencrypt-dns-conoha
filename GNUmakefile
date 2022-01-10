
all:

clean:
	find . -type f -name '*~' -delete 
	find . -type f -name "tmp.*" -delete

install:
	if [ ! -d /var/lib/letsencrypt/letsencrypt-dns-conoha ]; then mkdir /var/lib/letsencrypt/letsencrypt-dns-conoha ; fi 
	for file in conoha-acme-challenge.sh conoha_identity_api.sh ; do install "$$file" /var/lib/letsencrypt/letsencrypt-dns-conoha ; done 
