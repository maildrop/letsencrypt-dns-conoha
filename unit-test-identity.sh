#!/bin/bash

SCRIPT_PATH=$(dirname $(readlink -f $0))
. ${SCRIPT_PATH}/conoha_identity_api.sh
echo $(get_conoha_identity_token_json)
echo $(get_conoha_identity_token)

