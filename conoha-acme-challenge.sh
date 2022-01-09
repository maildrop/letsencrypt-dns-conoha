#!/bin/bash

PATH=/bin:/usr/bin

if [ -z "$CERTBOT_DOMAIN" ] ; then
    CERTBOT_DOMAIN=$(hostname -f)
fi
if [ -z "$CERTBOT_VALIDATION" ] ; then
    CERTBOT_VALIDATION="dummy data $(date)"
fi

SCRIPT_PATH=$(dirname $(readlink -f $0))
. ${SCRIPT_PATH}/conoha_identity_api.sh

if [ -z "${CNH_TOKEN}" ] ; then
    echo identity token is not defined
    exit 3
fi

if [ -z "${CNH_DNS_DOMAIN}" ] ; then
    CNH_DNS_DOMAIN=_acme-challenge.${CERTBOT_DOMAIN}'.'
fi

if [ -z "${CNH_DNS_TYPE}" ] ; then
    CNH_DNS_TYPE=TXT
fi

if [ -z "${CNH_DNS_DATA}" ] ; then
    CNH_DNS_DATA=${CERTBOT_VALIDATION}
fi

domains=$(curl -X GET \
	       -H "Accept: application/json" \
	       -H "Content-Type: application/json" \
	       -H "X-Auth-Token: ${CNH_TOKEN}" \
	       -sS "$(get_conoha_identity_endpoint_dns)/v1/domains" );

function listup_candidate_domain(){
    domain=$1
    shift
    for TARGET_CONOHA_DOMAIN in $* ; do
	RECORD_NAME=${domain%%${TARGET_CONOHA_DOMAIN}}
	if [ "${RECORD_NAME%%.}.${TARGET_CONOHA_DOMAIN}" = "${CNH_DNS_DOMAIN}" ] ; then 
	    echo ${TARGET_CONOHA_DOMAIN}
	fi
    done
}

# 候補となるドメイン群の中から、最長のドメインを選択する。

selected_domain=$(listup_candidate_domain $CNH_DNS_DOMAIN $(jq -r ".domains[] |  .name " <<< $domains ) | awk '{l=length($0); if (m<l) { m = l ; ll=$0 } }END{print ll}')
if [ -z "$selected_domain" ] ; then
    echo not found.
    exit 3
fi

# domain id を取得する
selected_domain_id=$(jq -r ".domains[] | select( .name ==\"${selected_domain}\" ) | .id " <<< $domains)
# $(jq -r ".domains[] | select( .name ==\"${selected_domain}\" ) | .id " <<< $domains)
# echo $selected_domain "(domainid: $(jq -r ".domains[] | select( .name ==\"${selected_domain}\" ) | .id " <<< $domains))"  ${record_name%%.}

#record_name=${CNH_DNS_DOMAIN%%${selected_domain}}

function do_update_dns_record() {
    records=$(curl -sS -X GET \
		   -H "Accept: application/json" \
		   -H "Content-Type: application/json" \
		   -H "X-Auth-Token: $1" \
		   "$(get_conoha_identity_endpoint_dns)/v1/domains/$2/records" )
    record_id=$(jq -r ".records[] | select( .name == \"${CNH_DNS_DOMAIN}\" and .type == \"${CNH_DNS_TYPE}\" )  | .id " <<< $records)

    if [ -z "${record_id}" ] ; then
	curl -sS "$(get_conoha_identity_endpoint_dns)/v1/domains/$2/records" \
	     -X POST \
	     -H "Accept: application/json" \
	     -H "Content-Type: application/json" \
	     -H "X-Auth-Token: $1" \
	     -d "{ \"name\": \"$(jq -r ".name" <<< $3)\", \
	     	   \"type\": \"$(jq -r ".type" <<< $3)\", \
		   \"data\": \"$(jq -r ".data" <<< $3)\", \
		   \"description\": \"Let's Encrypt ACME Challenge\",
		   \"ttl\": 60 }"
    else
	curl -sS "$(get_conoha_identity_endpoint_dns)/v1/domains/$2/records/${record_id}" \
	     -X PUT \
	     -H "Accept: application/json" \
	     -H "Content-Type: application/json" \
	     -H "X-Auth-Token: $1" \
	     -d "{ \"name\": \"$(jq -r ".name" <<< $3)\", \
	     	   \"type\": \"$(jq -r ".type" <<< $3)\", \
		   \"data\": \"$(jq -r ".data" <<< $3)\", \
		   \"description\": \"Let's Encrypt ACME Challenge\",
		   \"ttl\": 60 }"
    fi
}

do_update_dns_record ${CNH_TOKEN} ${selected_domain_id} "{\"name\": \"${CNH_DNS_DOMAIN}\" , \"type\": \"${CNH_DNS_TYPE}\", \"data\": \"${CNH_DNS_DATA}\" }" > /dev/null

sleep 180;
