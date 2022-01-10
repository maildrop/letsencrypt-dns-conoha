#!/bin/sh

PATH=/bin:/usr/bin

if [ -f "${PWD}/conoha_id" ] ; then
    . "${PWD}/conoha_id"
fi

echo "You see https://manage.conoha.jp/API/" 

if [ -z "$CNH_TENANTID" ] ; then
    echo -n "TenantID: " 
else
    echo "Current TenantID is \"$CNH_TENANTID\""
    echo -n "TenantID: " 
fi
read input_string 
if [ ! -z "$input_string" ] ; then
    CNH_TENANTID=$input_string
fi


if [ -z "$CNH_NAME" ] ; then
    echo -n "API UserName: "
else
    echo "Current API UserName is \"$CNH_NAME\""
    echo -n "API UserName: "
fi
read input_string

if [ ! -z "$input_string" ] ; then
    CNH_NAME=$input_string
fi


if [ -z "$CNH_PASS" ] ; then
    echo -n "API Password: "
else
    echo "You have API Password: ***"
    echo -n "API Passord: "
fi

stty -echo 
read input_string
stty echo 
echo ""

if [ ! -z "$input_string" ] ; then
    CNH_PASS=$input_string
fi

f=$(mktemp --tmpdir="$PWD")

if [ -f "$f" ] ; then
    chmod 600 "$f"
    cat <<EOF > "$f"
# Let's Encrypt certbot ACME protcol dns-01 challenge ahthentication data
# $(date)
#

CNH_NAME=${CNH_NAME}
CNH_PASS=${CNH_PASS}
CNH_TENANTID=${CNH_TENANTID}
EOF
fi

mv "$f" conoha_id

