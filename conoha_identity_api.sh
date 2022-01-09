#!/bin/bash

# -------- #
# VARIABLE #
# -------- #
SCRIPT_PATH=$(dirname $(readlink -f $0))

if [ -d "${SCRIPT_PATH}" ] && [ -f "${SCRIPT_PATH}/conoha_id" ]; then
    . "${SCRIPT_PATH}/conoha_id"
fi

# check conoha_identity file
if [ -z "${CNH_NAME}" ] ; then
    echo ${CNH_NAME}
    echo \${CNH_NAME} not defined.
    exit 3
fi

if [ -z "${CNH_PASS}" ] ; then
    echo \${CNH_PASS} not defined.
    exit 3
fi

if [ -z "${CNH_TENANTID}" ] ; then
    echo \${CNH_TENANTID} not defined.
    exit 3
fi

conoha_identity_token_json=$(curl -sS https://identity.tyo1.conoha.io/v2.0/tokens \
				  -X POST \
				  -H "Accept: application/json" \
				  -d '{ "auth": { "passwordCredentials": { "username": "'${CNH_NAME}'", "password": "'${CNH_PASS}'" }, "tenantId": "'${CNH_TENANTID}'" } }' )

get_conoha_identity_token_json(){
    cat <<< ${conoha_identity_token_json};
}

get_conoha_identity_token(){
    jq -r ".access.token.id" <<< $(get_conoha_identity_token_json)
}

get_conoha_identity_endpoint_dns(){
    jq -r '.access.serviceCatalog[] | select( .type == "dns" ) | .endpoints[].publicURL'  \
       <<< $(get_conoha_identity_token_json)
}

CNH_TOKEN=$(get_conoha_identity_token)

