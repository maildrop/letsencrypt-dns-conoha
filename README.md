# letsencrypt-dns-conoha

## Overview
Script to get Let's Encrypt Wildcard SSL Certificate using DNS in ConoHa VPS.

```
conoha-acme-challenge2.sh conoha dns acme challenge utility
 usage conoha-acme-challenge2.sh [-h] [-v] [-r] [-i <conoha id file>] [-f <fqdn>] [-t <challagne token>]
   -h : help
   -v : verbose
   -n : no-wait
   -r : remove
   -i <conoha_id file> : conoha_id file
   -f <fqdn> : specify fqdn default $(hostname -f) = "frederica.iogilab.net"
   -t <challange token> : specify acme challange token

 for debug usage
  show conoha_id: conoha-acme-challenge2.sh -vh
  add test challange token: conoha-acme-challenge2.sh -vn
  remove test challenge token: conoha-acme-challenge2.sh -vr
```

## Change
- Used conoha identity service to get DNS endpoint.
- Added support for non-wildcard hosts.
-- Added TXT record of _acme-challenge to the longest matching managed domain for the target host.

## Requirements
- CentOS7
- certbot 0.22.0+
- jq
- curl ( with debian 11 )
- DNS to manage your domain with ConoHa VPS.

## Setup
- Place code in your server.
- Set username, password and tenantId in the conoha_id

## Usage
- Test to get Wildcard SSL Certificate.
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
--manual-auth-hook /path/to/letsencrypt-dns-conoha/create_conoha_dns_record.sh \
--manual-cleanup-hook /path/to/letsencrypt-dns-conoha/delete_conoha_dns_record.sh
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
--manual-auth-hook /path/to/letsencrypt-dns-conoha/create_conoha_dns_record.sh \
--manual-cleanup-hook /path/to/letsencrypt-dns-conoha/delete_conoha_dns_record.sh
```

- Test to renew Wildcard SSL Certificate.
```
# certbot renew --force-renewal --dry-run
```

- Renew Wildcard SSL Certificate.
```
# certbot renew
```

## References
- [Pre and Post Validation Hooks](https://certbot.eff.org/docs/using.html#pre-and-post-validation-hooks)
- [ACME v2 Production Environment & Wildcards](https://community.letsencrypt.org/t/acme-v2-production-environment-wildcards/55578)
- [ConoHa API Documantation](https://www.conoha.jp/docs/)

## Licence
This software is released under the MIT License.
