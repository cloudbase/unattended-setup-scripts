#!/bin/bash
set -e

INSTANCE_ID=$1


echo "Getting Identity version"

URL=`curl -s -k -X 'GET' $OS_AUTH_URL | python -c "import json; import sys; d=json.load(sys.stdin); print d['versions']['values'][0]['id'] + ' ' + d['versions']['values'][0]['links'][0]['href']"`
IDENTITY_URL=`echo $URL | awk '{print $2}'`
IDENTITY_VERSION=`echo $URL | awk '{print $1}'`
if [[ $IDENTITY_VERSION = *"v3"* ]]; then
    IDENTITY_VERSION="v3"
else
    IDENTITY_VERSION="v2"
fi


echo "Getting Keystone token"

if [ $IDENTITY_VERSION = "v3" ]; then
    TOKENS_RESP=`curl -s -k -X 'POST' $IDENTITY_URL/auth/tokens -d '{"auth":{"identity":{"methods":["password"],"password":{"user":{"domain":{"name":"'$OS_PROJECT_DOMAIN_ID'"},"name":"'$OS_USERNAME'","password":"'$OS_PASSWORD'"}}},"scope":{"project":{"domain":{"name":"'$OS_PROJECT_DOMAIN_ID'"},"name":"'$OS_PROJECT_NAME'"}}}}' -D headerfile -H 'Content-type: application/json'`
    TOKEN=`grep -e X-Subject-Token headerfile | awk '{print substr($0,18,length($0))}' | awk '{print substr($0,0,length($0)-1)}'` #remove "X-Subject-Token: " from the beginning
    rm headerfile
    NOVA_URL=`echo $TOKENS_RESP | python -c "import json; import sys; d=json.load(sys.stdin); print([endpoint['url'] for endpoint in [serviceCatalog['endpoints'][0] for serviceCatalog in d['token']['catalog'] if serviceCatalog['name'] == 'nova']][0])"`
else
    TOKENS_RESP=`curl -s -k -X 'POST' $OS_AUTH_URL/tokens -d '{"auth":{"passwordCredentials":{"username": "'$OS_USERNAME'", "password":"'$OS_PASSWORD'"}, "tenantName":"'$OS_TENANT_NAME'"}}'     -H 'Content-type: application/json'`
    TOKEN=`echo $TOKENS_RESP | python -c "import json; import sys; d=json.load(sys.stdin); print d['access']['token']['id']"`
    NOVA_URL=`echo $TOKENS_RESP | python -c "import json; import sys; d=json.load(sys.stdin); print([c for c in d['access']['serviceCatalog'] if c['name'] == 'nova'][0]['endpoints'][0]['adm    inURL'])"`
fi


echo "Getting Compute version"

NOVA_VERSION="v2"
if [[ $NOVA_URL = *"v2.1"* ]];then
    NOVA_VERSION="v2.1"
fi


echo "Getting RDP console"

if [ $NOVA_VERSION == "2" ]; then
    CONSOLE_RESP=`curl -s -H "X-Auth-Token: $TOKEN" $NOVA_URL/servers/$INSTANCE_ID/action -X "POST" -H 'Content-type: application/json' -d '{"os-getRDPConsole":{"type":"rdp-html5"}}'`
    KEYWORD="console"
else
    CONSOLE_RESP=`curl -s -X POST $NOVA_URL/servers/$INSTANCE_ID/remote-consoles -H "Accept: application/json" -H "OpenStack-API-Version: compute 2.53" -H "X-OpenStack-Nova-API-Version: 2.53" -H "X-Auth-Token: $TOKEN" -H "Content-Type: application/json" -d '{"remote_console": {"type": "rdp-html5", "protocol": "rdp"}}'`
    KEYWORD="remote_console"
fi

CONSOLE_URL=`echo $CONSOLE_RESP | python -c "import json; import sys; d=json.load(sys.stdin); print d['$KEYWORD']['url']"`
CONSOLE_TOKEN=${CONSOLE_URL#*=}

echo $CONSOLE_TOKEN


echo "Getting console connect info"

GET_CONSOLE_CONN_RESP=`curl -s -H "X-Auth-Token: $TOKEN" $NOVA_URL/os-console-auth-tokens/$CONSOLE_TOKEN -X "GET" -H 'Content-type: application/json'`

#echo $GET_CONSOLE_CONN_RESP

HOST=`echo $GET_CONSOLE_CONN_RESP | python -c "import json; import sys; d=json.load(sys.stdin); print d['console']['host']"`
PORT=`echo $GET_CONSOLE_CONN_RESP | python -c "import json; import sys; d=json.load(sys.stdin); print d['console']['port']"`
INTERNAL_ACCESS_PATH=`echo $GET_CONSOLE_CONN_RESP | python -c "import json; import sys; d=json.load(sys.stdin); print d['console']['internal_access_path']"`

echo "Host: $HOST"
echo "Port: $PORT"
echo "Internal_access_path: $INTERNAL_ACCESS_PATH"
