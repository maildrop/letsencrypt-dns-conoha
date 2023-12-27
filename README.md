# letsencrypt-dns-conoha

## Overview
Script to get Let's Encrypt Wildcard SSL Certificate using DNS in ConoHa VPS.

## Requirements
- Debian 11
- certbot 0.22.0+
- jq
- curl
- DNS to manage your domain with ConoHa VPS.

## Change
- Used conoha identity service to get DNS endpoint.
- Added support for non-wildcard hosts.
    - Added TXT record of _acme-challenge to the longest matching managed domain for the target host.

```
$ /usr/libexec/conoha-acme-challenge/conoha-acme-challenge.sh -h
you cannot read conoha_id file /etc/conoha_id , use -i option
usage: conoha-acme-challenge.sh [-h] [-v] [-r] [-n] [-i conoha_id] [-f certbot_domain] [-t certbot_validation] [fqdn....]
 -h : show this Help message.
 -v : verbose
 -r : remove
 -f : certbot_domain (conma separated , override ${CERTBOT_DOMAIN} for debugging or manual operation)
 -n : nowait (for debugging or manual operation)
 -i : conoha_id file 
 -t : certbot_validation (override ${CERTBOT_VALIDATION} for debugging or manual operation)
```

```
for debug usage
  show conoha_id: conoha-acme-challenge.sh -vh
  add test challange token: conoha-acme-challenge.sh -vn -i /etc/conoha_id -f $(hostname -f) 
  remove test challenge token: conoha-acme-challenge.sh -vr -i /etc/conoha_id -f $(hostname -f) 
```

## journalctl
You can see conoha-acme-challange.sh script communication log.
```
$ journalctl -t conoha-acme-challenge.sh
```

## .deb package build
- use ```make deb-package``` 

# Usage

## Setup
- build ```make deb-package```
- install ```dpkg -i letsencrypt-dns-conoha_0.0.2-2_all.deb```
- use ```/usr/sbin/create-conoha_id``` for Set username, password and tenantId in the conoha_id 
```
The default conoha_id file location has been changed to /etc/conoha_id.
```
- Test to get Wildcard SSL Certificate.


```
= NOTE =
cerate_conoha_dns_record.sh waits until the DNS records are actually applied on the servers listed in the NS records.
It takes a few minutes for certbot to run.
 (It depends on the mood of the DNS server, but please watch it for about 10 minutes.)
This wait can be very long. (wait up to 60 minutes. )

conoha-acme-challenge.sh has an option "-n" to cancel this wait .
```

```
# certbot certonly \
--dry-run \
--manual \
--agree-tos \
--no-eff-email \
--manual-public-ip-logging-ok \
--preferred-challenges dns-01 \
--server https://acme-v02.api.letsencrypt.org/directory \
-d "<base domain name>" \
-d "*.<base domain name>" \
-m "<mail address>" \
--manual-auth-hook /var/lib/letsencrypt/letsencrypt-dns-conoha/create_conoha_dns_record.sh \
--manual-cleanup-hook /var/lib/letsencrypt/letsencrypt-dns-conoha/delete_conoha_dns_record.sh
```

- Get Wildcard SSL Certificate.
```
# certbot certonly \
--manual \
--agree-tos \
--no-eff-email \
--manual-public-ip-logging-ok \
--preferred-challenges dns-01 \
--server https://acme-v02.api.letsencrypt.org/directory \
-d "<base domain name>" \
-d "*.<base domain name>" \
-m "<mail address>" \
--manual-auth-hook /var/lib/letsencrypt/letsencrypt-dns-conoha/create_conoha_dns_record.sh \
--manual-cleanup-hook /var/lib/letsencrypt/letsencrypt-dns-conoha/delete_conoha_dns_record.sh
```

- Test to renew Wildcard SSL Certificate.
```
# certbot renew --force-renewal --dry-run
```

- Renew Wildcard SSL Certificate.
```
# certbot renew
```

# Change Log
0.0.2
When I tried to issue certificates for wildcards and the domains themselves (for example, certificates for *.example.com and example.com), multiple TXT records were required, so I stopped using UPSERT and instead used APPEND.
In line with this, changes have been made to delete multiple TXT records when removing.


## References
- [Pre and Post Validation Hooks](https://certbot.eff.org/docs/using.html#pre-and-post-validation-hooks)
- [ACME v2 Production Environment & Wildcards](https://community.letsencrypt.org/t/acme-v2-production-environment-wildcards/55578)
- [ConoHa API Documantation](https://www.conoha.jp/docs/)

## Licence
This software is released under the MIT License.
