#!/bin/sh

if [ -x /usr/libexec/conoha-acme-challenge/conoha-acme-challenge.sh ] ; then
    /usr/libexec/conoha-acme-challenge/conoha-acme-challenge.sh -r
fi
