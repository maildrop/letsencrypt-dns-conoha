#!/bin/bash -eu

PATH=/bin:/usr/bin
export PATH

_canonical_domain () {
    echo "$(echo "$1" | tr -d '[:space:]'| sed -E -e 's/\.+/./g' | sed -E -e 's/^[[:space:]]*\*?\.//' | sed -E -e 's/\.$//' )."
}

_logger_alert() {
    logger -p user.alert -t "${0##*/}" "$(printf "$@")"
}

_logger_notice () {
    logger -p user.notice -t "${0##*/}" "$(printf "$@")"
}

_logger_info () {
    logger -p user.info -t "${0##*/}" "$(printf "$@")"
}

_logger_debug () {
    logger -p user.debug -t "${0##*/}" "$(printf "$@")"
}

domain_uuid (){
    local domain=$1
    jq -r ".domains[] | select ( .name == \"${domain}\" ) | .id " <<< $domains_json;    
}

append_record () {
    # $1 validation string
    # $2 domain
    _logger_info 'create record "_acme-challenge.%s" on "%s"' "$2" "${selected_domain}"
    jq -c . <<EOF | curl -Ss -X POST --data @- \
                         -H "Accept: application/json" \
                         -H "Content-Type: application/json" \
                         -H "X-Auth-Token: ${CNH_TOKEN}" \
                         "${dns_endpoint}/v1/domains/$(domain_uuid "$selected_domain")/records" | \
        jq -c '. + {data: "*******************"}'  | logger -p user.notice -t "${0##*/}"
{       
  "name": "_acme-challenge.$2",
  "type": "TXT",
  "data": "$1",
  "description": "Let's Encrypt Certbot DNS ACME challenge validation key",
  "ttl": 60
}
EOF
    request_wait="yes"
}

remove_record () {
    # $1 validation string
    # $2 domain
    _logger_notice 'DELETE _achme-challenge.%s 60 IN TXT "%s"' "$2" "*****"

    local domain_records=$(curl -sS -X GET \
                                 -H "Accept: application/json" \
                                 -H "Content-Type: application/json" \
                                 -H "X-Auth-Token: ${CNH_TOKEN}" \
                                 "${dns_endpoint}/v1/domains/$(domain_uuid "$selected_domain")/records" )
    
    for uuid_of_record in $(jq -r ".records[] | select ( .name == \"_acme-challenge.$2\" and .type == \"TXT\" ) | .id " <<< $domain_records) ; do
        _logger_notice "DELETE RECORD _acme-challenge.$2 ($uuid_of_record)"
        curl -Ss -X DELETE \
             -H "Accept: application/json" \
             -H "Content-Type: application/json" \
             -H "X-Auth-Token: ${CNH_TOKEN}" \
             "${dns_endpoint}/v1/domains/$(domain_uuid "$selected_domain")/records/${uuid_of_record}"
    done
}

# request_authtoken() {
#     if [ -n "${verbose:-}" ] ; then echo -n "fetch conoha identity token from ${identity_service:-https://identity.tyo1.conoha.io/v2.0} ..." ; fi

# }

wait_update_of_nameserver () {
    # $1 selected_domain
    # $2 CLASS (ex. "TXT"
    # $3 ${CERTBOT_DOMAIN}
    # $4 ${CERTBOT_VALIDATION}
   
    for nameserver in $(dig NS "$1" +short) ; do
        if [ -n "${verbose:-}" ] ; then echo -n $nameserver ": " ; fi
        local validate=
        for i in $(seq 60) ; do
            for value in $(dig "@$nameserver" $2 $3 +short) ; do
                if [ "$value" = "\"$4\"" ] ; then
                    validate=yes
                    break
                fi
            done

            if [ -n "${validate:-}" ]; then
                break
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

process_record () {
    local -r selected_domain=$(listup_candidate_domain "$1" "${management_domains[@]}" | awk '{l=length($0); if (m<l) { m = l ; ll=$0 } }END{print ll}')
    if [ -z "${selected_domain}" ] ; then
        _logger_alert '"%s" is not under control domain.' "$1"
        return 1;
    fi
    if [ -z "${remove_opt}" ] ; then
        append_record "${validation}" "$1"
    else
        remove_record "${validation}" "$1"
    fi
}

process () {
    _logger_debug '$0=%s, pwd="%s", domains="%s"' \
                  "$(realpath -e "$0")" \
                  "$PWD" \
                  "$*"

    for fqdn in "$@" ; do process_record "$fqdn" ; done

    if [ -z "$nowait_opt" ] && [ -n "$request_wait" ] ; then
        for fqdn in "$@" ; do
            wait_update_of_nameserver "$(listup_candidate_domain "${fqdn}" "${management_domains[@]}" | awk '{l=length($0); if (m<l) { m = l ; ll=$0 } }END{print ll}')" \
                                      "TXT" "_acme-challenge.${fqdn}"  "${validation}"
        done
    fi
}

help (){
    echo "usage: ${0##*/} [-h] [-v] [-r] [-n] [-i conoha_id] [-f certbot_domain] [-t certbot_validation] [fqdn....]"
    echo " -h : show this Help message." 
    echo " -v : verbose"
    echo " -r : remove"
    echo " -f : certbot_domain (conma separated , override \${CERTBOT_DOMAIN} for debugging or manual operation)"
    echo " -n : nowait (for debugging or manual operation)"
    echo " -i : conoha_id file "
    echo " -t : certbot_validation (override \${CERTBOT_VALIDATION} for debugging or manual operation)"
    echo "# Configuration #"
    printf " - conoha_id=%s\n" "$conoha_id"
    printf " - validation=%s\n" "$validation"
    printf " - identity_service=%s\n" "${identity_service:-https://identity.tyo1.conoha.io/v2.0}"

}


main ( ) {
    local -
    set -o noglob

    local verbose=
    local fqdn_list=()
    local canonicalaized_list=()
    local show_help=
    local remove_opt=
    local nowait_opt=
    local validation=${CERTBOT_VALIDATION:-$(date "+DUMMYACMECHALLENGE%Y%m%d-%s-$(hostname -f)")}
    local conoha_id=/etc/conoha_id
    local request_wait=
    while getopts "hrvni:f:t:" opt 
    do
        case $opt in
            h)  show_help=yes;;
            v)  verbose=yes;;
            r)  remove_opt=yes;;
            f)  fqdn_opt=$OPTARG;;
            n)  nowait_opt=yes;;
            i)  conoha_id=$OPTARG;;
            t)  validation=$OPTARG;;
            *)
                echo "unkonwn ${opt}"
                exit 3
                ;;
        esac
    done
    shift $(($OPTIND - 1 ))

    if [ -f "$conoha_id" ] ; then
        if [ -r "$conoha_id" ] ; then
            . "$conoha_id"
        else
            echo "you cannot read conoha_id file $conoha_id , use -i option"
        fi
    else
        echo "you cannot read conoha_id file $conoha_id , use -i option"
    fi
    
    fqdn_list+=($(for param in $( tr ',' ' ' <<< "${fqdn_opt:-${CERTBOT_DOMAIN:-}}" ) ; do \
                      echo $(_canonical_domain "$param" );\
                  done))

    for param in "$@" ; do
        local canonicalized=$(_canonical_domain "$param" )
        fqdn_list+=($canonicalized)
    done

    local -r cfqdn_list=( $(sort  <<< $(for domain in "${fqdn_list[@]}"; do echo $domain ; done) | uniq) )
    
    if [ -n "${show_help}" ]; then
        help
        if [ -z "${verbose:-}" ] ; then
            return 0
        fi
    fi

    if [ -n "${verbose:-}" ] ; then echo -n "fetch conoha identity token from ${identity_service:-https://identity.tyo1.conoha.io/v2.0} ..." ; fi

    if [ -z "${CNH_NAME:-}" ] || [ -z "${CNH_PASS:-}" ] || [ -z "${CNH_TENANTID:-}" ] ; then
        echo 
        echo conoha_id error
        if [ -f "${conoha_id}" ] ; then
            echo "The file \"${conoha_id}\" is not readable."
            echo "check \"${conoha_id}\" permission."
            echo "or use -i option"
        else
            echo "The file \"${conoha_id}\" is not found."
            echo "You can use \"/usr/sbin/create-conoha_id\" to create \"${conoha_id}\" "
        fi
        echo 
        return 3
    fi
    
    local -r conoha_identity_token_json=$(jq -c . <<EOF \
                                              | curl -sS "${identity_service:-https://identity.tyo1.conoha.io/v2.0}/tokens" \
                                                     -X POST -H "Accept: application/json" --data @- 
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

    if [ -n "${verbose:-}" ] ; then echo " done." ; fi

    local -r CNH_TOKEN=$(jq -r ".access.token.id" <<< $conoha_identity_token_json)
    local -r identity_endpoint=$(jq -r '.access.serviceCatalog[] | select( .type == "identity" ) | .endpoints[].publicURL' <<< ${conoha_identity_token_json})
    local -r dns_endpoint=$(jq -r '.access.serviceCatalog[] | select( .type == "dns" ) | .endpoints[].publicURL' <<< ${conoha_identity_token_json})
    local -r databasehosting_endpoint=$(jq -r '.access.serviceCatalog[] | select( .type == "databasehosting" ) | .endpoints[].publicURL' <<< ${conoha_identity_token_json})
    local -r objectstore_endpoint=$(jq -r '.access.serviceCatalog[] | select( .type == "object-store" ) | .endpoints[].publicURL' <<< ${conoha_identity_token_json})

    if [ -n "${verbose:-}" ] ; then
        echo "==== Service endpoint ===="
        printf "CNH_TOKEN=%s\n" $CNH_TOKEN 
        printf "Identity endpoint=%s\n" ${identity_endpoint}
        printf "DNS endpoint=%s\n"  ${dns_endpoint}
        printf "Database Hosting endpoint=%s\n" ${databasehosting_endpoint} 
        printf "Object Storage endpoint=%s\n" ${objectstore_endpoint}
        echo "=========================="
        echo 
    fi
    
    if [ -n "${verbose:-}" ] ; then
        echo = Domains =
        for fqdn in "${fqdn_list[@]}" ; do
            echo " - \"$fqdn\""
        done
        echo -n "fetch conoha dns domains ${dns_endpoint}/v1/domains ...";
    fi

    local -r domains_json=$(curl -sS -X GET \
                                   -H "Accept: application/json" \
                                   -H "Content-Type: application/json" \
                                   -H "X-Auth-Token: ${CNH_TOKEN}" \
                                   "${dns_endpoint}/v1/domains");

    if [ -n "${verbose:-}" ] ; then echo " done"; fi
    local management_domains=()
    for domain in $(jq -r ".domains[] | .name " <<< $domains_json) ; do
        management_domains+=($domain)
    done

    function listup_candidate_domain(){
        local -r domain=$1
        local RECORD_NAME=
        shift
        for TARGET_CONOHA_DOMAIN in $@ ; do
            if [ "$domain" = "$TARGET_CONOHA_DOMAIN" ] ; then
                echo $TARGET_CONOHA_DOMAIN;
            else
                RECORD_NAME="${domain%${TARGET_CONOHA_DOMAIN}}"
                if [ "${RECORD_NAME%.}.${TARGET_CONOHA_DOMAIN}" = "${domain}" ] ; then 
                    echo ${TARGET_CONOHA_DOMAIN}
                fi
            fi
        done
    }
    
    if [ -n "${verbose:-}" ] ; then
        echo "=management domain list="
        for domain in "${management_domains[@]}" ; do
            printf "[%s] (uuid=\"%s\")\n" "$domain" $(domain_uuid "$domain")
            for fqdn in "${cfqdn_list[@]}" ; do
                local selected_domain=$(listup_candidate_domain "${fqdn}" "${management_domains[@]}" | awk '{l=length($0); if (m<l) { m = l ; ll=$0 } }END{print ll}')
                if [ "$selected_domain" = "$domain" ]; then
                    printf "  _acme-challenge.%s\n" "$fqdn"
                fi
            done
        done
        echo "======================="
        echo 
    fi

    if [ -n "${show_help}" ]; then
        return 0
    fi
    process "${cfqdn_list[@]}"

}

check_environment(){
    local c
    for c in jq curl; do
        if [ -z "$(which $c)" ]; then
            echo "command $c is not found in $PATH"
            return 3
        fi
    done
    return 0
}

check_environment 
main "$@"
