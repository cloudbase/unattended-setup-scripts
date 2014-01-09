#!/bin/bash
set -e

INSTANCE_ID=eaea9be1-d12f-47ea-ad79-7d73cedf0cea

TOKENS_RESP=`curl -s -k -X 'POST' $OS_AUTH_URL/tokens -d '{"auth":{"passwordCredentials":{"username": "'$OS_USERNAME'", "password":"'$OS_PASSWORD'"}, "tenantName":"'$OS_TENANT_NAME'"}}' -H 'Content-type: application/json'`
TOKEN=`echo $TOKENS_RESP | python -c "import json; import sys; d=json.load(sys.stdin); print d['access']['token']['id']"`
NOVA_URL=`echo $TOKENS_RESP | python -c "import json; import sys; d=json.load(sys.stdin); print d['access']['serviceCatalog'][0]['endpoints'][0]['adminURL']"`

CONSOLE_RESP=`curl -s -H "X-Auth-Token: $TOKEN" $NOVA_URL/servers/$INSTANCE_ID/action -X "POST" -H 'Content-type: application/json' -d '{"os-getVNCConsole":{"type":"novnc"}}'`

CONSOLE_URL=`echo $CONSOLE_RESP | python -c "import json; import sys; d=json.load(sys.stdin); print d['console']['url']"`
CONSOLE_TOKEN=`echo $CONSOLE_URL | sed -n 's/.*token\=\(.\+\)/\1/p'`

GET_CONSOLE_CONN_RESP=`curl -s -H "X-Auth-Token: $TOKEN" $NOVA_URL/servers/$INSTANCE_ID/action -X "POST" -H 'Content-type: application/json' -d '{"os-getConsoleConnectInfo":{"token":"'$CONSOLE_TOKEN'"}}'`

echo $GET_CONSOLE_CONN_RESP

HOST=`echo $GET_CONSOLE_CONN_RESP | python -c "import json; import sys; d=json.load(sys.stdin); print d['host']"`
PORT=`echo $GET_CONSOLE_CONN_RESP | python -c "import json; import sys; d=json.load(sys.stdin); print d['port']"`
INTERNAL_ACCESS_PATH=`echo $GET_CONSOLE_CONN_RESP | python -c "import json; import sys; d=json.load(sys.stdin); print d['internal_access_path']"`

echo "Host: $HOST"
echo "Port: $PORT"
echo "Internal_access_path: $INTERNAL_ACCESS_PATH"
