#!/bin/bash
set -e

VOLUME_TYPE_ID=$1

TOKENS_RESP=`curl -s -k -X 'POST' $OS_AUTH_URL/tokens -d '{"auth":{"passwordCredentials":{"username": "'$OS_USERNAME'", "password":"'$OS_PASSWORD'"}, "tenantName":"'$OS_TENANT_NAME'"}}' -H 'Content-type: application/json'`
TOKEN=`echo $TOKENS_RESP | python -c "import json; import sys; d=json.load(sys.stdin); print d['access']['token']['id']"`
CINDER_URL=`echo $TOKENS_RESP | python -c "import json; import sys; d=json.load(sys.stdin); print([c for c in d['access']['serviceCatalog'] if c['name'] == 'cinder'][0]['endpoints'][0]['adminURL'])"`

VOLUME_TYPE=`curl -s -H "X-Auth-Token: $TOKEN" $CINDER_URL/types/$VOLUME_TYPE_ID -H 'Content-type: application/json'`
echo $VOLUME_TYPE

