#!/usr/bin/env -S bash -eu
# -*- sh-shell: bash; coding: utf-8-unix -*- 
#

PATH=/bin:/usr/bin
export PATH

declare curl=$(which curl)
declare jq=$(which jq)
declare dryrun=
declare verbose=
declare nowait=
declare remove_record=
declare identity_file="conoha_id"
declare certbot_domain=${CERTBOT_DOMAIN:-$(hostname -f).}
declare certbot_validation=${CERTBOT_VALIDATION:-DUMMY_DATA_AT_$certbot_domain $(date "+%Y-%m-%d %H:%d:%S%z")}

use_path () {
    echo "$(readlink -f "$(dirname $(readlink -e $0))/$1")"
}

use () {
    local target=$(use_path $1)
    if [ ! -f "$target" ]; then
        echo "$target" is not found.
        return 3
    fi
    source "$target"
    return 0
}

remove_trailing_dot () {
    if [ "$1" = "${1%%.}" ] ; then
        echo $1
    else
        remove_trailing_dot "${1%%.}"
    fi
}


print_help () {
    printf "%s conoha dns acme challenge utility\n" ${0##*/}
    printf " usage %s [-h] [-v] [-r] [-i <conoha id file>] [-f <fqdn>] [-t <challagne token>]\n" ${0##*/}
    printf "   -h : help\n"
    printf "   -v : verbose\n"
    printf "   -n : no-wait\n"
    printf "   -r : remove\n"
    printf "   -i <conoha_id file> : conoha_id file\n"
    printf "   -f <fqdn> : specify fqdn default \$(hostname -f). = \"%s\"\n" "$(hostname -f)."
    printf "   -t <challange token> : specify acme challange token\n" 
    printf "\n"
    printf " for debug usage\n"
    printf "  show conoha_id: %s -vh\n" ${0##*/} 
    printf "  add test challange token: %s -vn\n" ${0##*/} 
    printf "  remove test challenge token: %s -vr\n" ${0##*/}
    
    if [ -n "${verbose:-}" ] ; then
        echo 
        echo "= verbose ="
        echo curl=${curl}
        echo jq=${jq}
        echo identity_file=$(use_path ${identity_file})
        echo certbot_domain=${certbot_domain}
        echo certbot_validation=${certbot_validation}
        
        use ${identity_file};

        echo CNH_NAME=${CNH_NAME}
        echo CNH_PASS=$( if [ -n "${CNH_PASS}" ] ; then echo "***********************" ; else echo "" ; fi )
        echo CNH_TENANTID=${CNH_TENANTID}
    fi
}

while getopts vhnrdi:f:t: opt ; do
    case $opt in
        "v" )
            verbose=yes;;
        "h" )
            print_help
            exit 0
            ;;
        "n" )
            nowait=yes;;
        "r" )
            remove_record=yes;;
        "d" )
            dry_run=yes;;
        "i" )
            identity_file=$OPTARG;;
        "f" )
            certbot_domain="$(remove_trailing_dot "$OPTARG").";;
        "t" )
            certbot_validation=$OPTARG;;
        * )
        ;;
    esac
done
shift $(($OPTIND -1))

use ${identity_file}

if [ -n "${verbose:-}" ] ; then echo -n "fetch conoha identity token from ${identity_service:-https://identity.tyo1.conoha.io/v2.0} ..." ; fi

declare -r conoha_identity_token_json=$(jq -c . <<EOF | curl -sS "${identity_service:-https://identity.tyo1.conoha.io/v2.0}/tokens" \
                                                             -X POST -H "Accept: application/json" \
                                                             --data @- 
{
  "auth": {
    "passwordCredentials": {
      "username": "${CNH_NAME}" ,
      "password": "${CNH_PASS}" 
    },
    "tenantId": "${CNH_TENANTID}"
  }
}
EOF
        )
# jq <<< ${conoha_identity_token_json}

if [ -n "${verbose:-}" ] ; then echo " done." ; fi

declare -r CNH_TOKEN=$(jq -r ".access.token.id" <<< $(echo $conoha_identity_token_json))
declare -r identity_endpoint=$(jq -r '.access.serviceCatalog[] | select( .type == "identity" ) | .endpoints[].publicURL' <<< ${conoha_identity_token_json})
declare -r dns_endpoint=$(jq -r '.access.serviceCatalog[] | select( .type == "dns" ) | .endpoints[].publicURL' <<< ${conoha_identity_token_json})
declare -r databasehosting_endpoint=$(jq -r '.access.serviceCatalog[] | select( .type == "databasehosting" ) | .endpoints[].publicURL' <<< ${conoha_identity_token_json})
declare -r objectstore_endpoint=$(jq -r '.access.serviceCatalog[] | select( .type == "object-store" ) | .endpoints[].publicURL' <<< ${conoha_identity_token_json})

if [ -n "${verbose:-}" ] ; then
    echo "==== Service endpoint ===="
    printf "CNH_TOKEN=%s\n" $CNH_TOKEN 
    printf "Identity endpoint=%s\n" ${identity_endpoint}
    printf "DNS endpoint=%s\n"  ${dns_endpoint}
    printf "Database Hosting endpoint=%s\n" ${databasehosting_endpoint} 
    printf "Object Storage endpoint=%s\n" ${objectstore_endpoint}
    echo "=========================="
fi

if [ -n "${verbose:-}" ] ; then echo -n "fetch conoha dns domains ${dns_endpoint}/v1/domains ..."; fi
declare -r domains_json=$(curl -sS -X GET \
                               -H "Accept: application/json" \
                               -H "Content-Type: application/json" \
                               -H "X-Auth-Token: ${CNH_TOKEN}" \
                               "${dns_endpoint}/v1/domains");
if [ -n "${verbose:-}" ] ; then echo " done"; fi
declare management_domains=()

function listup_candidate_domain(){
    local domain=$1
    shift
    for TARGET_CONOHA_DOMAIN in $* ; do
        RECORD_NAME=${domain%%${TARGET_CONOHA_DOMAIN}}
        if [ "${RECORD_NAME%%.}.${TARGET_CONOHA_DOMAIN}" = "${domain}" ] ; then 
            echo ${TARGET_CONOHA_DOMAIN}
        fi
    done
}


for domain in $(jq -r ".domains[] | .name " <<< $domains_json) ; do
    management_domains+=($domain)
done

declare -r selected_domain=$(listup_candidate_domain ${certbot_domain} "${management_domains[@]}" | awk '{l=length($0); if (m<l) { m = l ; ll=$0 } }END{print ll}')

if [ -n "${verbose:-}" ] ; then
    echo "== under management domains - begin =="
    for domain in "${management_domains[@]}" ;do
        if [ "$domain" = "$selected_domain" ] ; then
            echo "+ $domain"
        else
            echo "  $domain"
        fi
    done
    echo "== under management domains -  end  =="
fi

if [ -z "$selected_domain" ]; then
    if [ -n "${verbose:-}" ] ; then echo "domain not found" ; fi 
    exit 3
fi

function domain_uuid (){
    local domain=$1
    jq -r ".domains[] | select ( .name == \"${selected_domain}\" ) | .id " <<< $domains_json;    
}

declare -r domain_records=$(curl -sS -X GET \
                                 -H "Accept: application/json" \
                                 -H "Content-Type: application/json" \
                                 -H "X-Auth-Token: ${CNH_TOKEN}" \
                                 "${dns_endpoint}/v1/domains/$(domain_uuid "$selected_domain")/records" )


# echo "_acme-challenge.${certbot_domain} : id = $(jq -r ".records[] | select ( .name == \"_acme-challenge.${certbot_domain}\" ) | .id " <<< $domain_records)"

wait_update_of_nameserver () {
    for nameserver in $(dig NS "$1" +short) ; do
        if [ -n "${verbose:-}" ] ; then echo -n $nameserver ": " ; fi
        local validate=
        for i in $(seq 6) ; do 
            if [ "$(dig "@$nameserver" $2 $3 +short)" = "\"$4\"" ] ; then
                validate=yes
                break;
            fi
            for j in $(seq 10); do
                if [ -n "${verbose:-}" ] ; then echo -n "." ; fi
                sleep 6s;
            done
        done
        if [ -n "${verbose:-}" ] ; then
            echo ". done." ;
            if [ -z "${validate:-}" ]; then
                echo fail on $nameserver ${validate:-}
            fi
        fi
    done
}

dns_record_push ( ){
    if [ -n "${verbose:-}" ] ; then echo -n "push dns record " ; fi 
    local response=
    if [ -n "$(jq -r ".records[] | select ( .type == \"TXT\" and .name == \"_acme-challenge.${certbot_domain}\" ) | .id " <<< $domain_records)" ] ; then
        if [ -n "${verbose:-}" ] ; then echo "update" ; fi 
        response=$(curl -Ss -X PUT \
                        -H "Accept: application/json" \
                        -H "Content-Type: application/json" \
                        -H "X-Auth-Token: ${CNH_TOKEN}" \
                        "${dns_endpoint}/v1/domains/$(domain_uuid "$selected_domain")/records/$(jq -r ".records[] | select ( .type == \"TXT\" and .name == \"_acme-challenge.${certbot_domain}\" ) | .id " <<< $domain_records)" --data @- <<EOF
{   
  "name": "_acme-challenge.${certbot_domain}",
  "type": "TXT",
  "data": "${certbot_validation}",
  "description": "Let's Encrypt Certbot DNS ACME challenge validation key",
  "ttl": 60
}
EOF
              )
    else
        if [ -n "${verbose:-}" ] ; then echo "create" ; fi 
        response=$(curl -Ss -X POST \
                              -H "Accept: application/json" \
                              -H "Content-Type: application/json" \
                              -H "X-Auth-Token: ${CNH_TOKEN}" \
                              "${dns_endpoint}/v1/domains/$(domain_uuid "$selected_domain")/records" \
                              --data @- <<EOF 
{                                        
  "name": "_acme-challenge.${certbot_domain}",
  "type": "TXT" ,                               
  "data": "${certbot_validation}",              
  "description": "Let's Encrypt Certbot DNS ACME challenge validation key",
  "ttl": 60             
}
EOF
              )
    fi
    if [ -n "${verbose:-}" ] ; then
        printf "%s IN %s \"%s\"\n" "$(jq -r ".name" <<< $response)" "$(jq -r ".type" <<< $response)" "$(jq -r ".data" <<< $response)" ;
    fi
}

dns_record_remove () {
    local response=
    if [ -n "$(jq -r ".records[] | select ( .type == \"TXT\" and .name == \"_acme-challenge.${certbot_domain}\" ) | .id " <<< $domain_records)" ] ; then
        response=$(curl -Ss -X DELETE \
             -H "Accept: application/json" \
             -H "Content-Type: application/json" \
             -H "X-Auth-Token: ${CNH_TOKEN}" \
             "${dns_endpoint}/v1/domains/$(domain_uuid "$selected_domain")/records/$(jq -r ".records[] | select ( .type == \"TXT\" and .name == \"_acme-challenge.${certbot_domain}\" ) | .id " <<< $domain_records)" )
    fi
    if [ -n "${verbose:-}" ] ; then echo $response; fi
}

if [ -z "${remove_record}" ]; then 
    dns_record_push
    if [ -z "${nowait:-}" ] ; then
        wait_update_of_nameserver ${selected_domain} "TXT" "_acme-challenge.${certbot_domain}" "${certbot_validation}"
    fi
else
    dns_record_remove
fi
