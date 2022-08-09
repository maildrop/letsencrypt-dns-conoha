#!/bin/sh
#
#
#

export PATH=/bin:/usr/bin

if [ ! -d /var/lib/letsencrypt/letsencrypt-dns-conoha ]; then
    sudo mkdir /var/lib/letsencrypt/letsencrypt-dns-conoha ;
fi

for file in conoha-acme-challenge.sh conoha_identity_api.sh create-conoha_id.sh ; do
    if [ -f "$(dirname $(realpath $0))/$file" ] ; then 
        sudo install "$(dirname $(realpath $0))/$file" /var/lib/letsencrypt/letsencrypt-dns-conoha ;
    fi
done 
