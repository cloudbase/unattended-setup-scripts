#!/bin/bash
set -e

USER_NAME=cloudbase-init-user-$RANDOM
UPN=$USER_NAME@localhost
SUBJECT="/CN=$USER_NAME"

PFX_FILE=winrm_client_cert.pfx
PEM_FILE=winrm_client_cert.pem

PRIVATE_DIR=`mktemp -d -t cloudbase-initXXXXXX`
chmod 700 $PRIVATE_DIR

EXT_CONF_FILE=`mktemp -t cloudbase-initXXXXXX.conf`

KEY_FILE=$PRIVATE_DIR/cert.key

cat > $EXT_CONF_FILE << EOF
distinguished_name  = req_distinguished_name
[req_distinguished_name]
[v3_req_client]
extendedKeyUsage = clientAuth
subjectAltName = otherName:1.3.6.1.4.1.311.20.2.3;UTF8:$UPN
EOF

export OPENSSL_CONF=$EXT_CONF_FILE
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -out $PEM_FILE \
-outform PEM -keyout $KEY_FILE -subj $SUBJECT \
-extensions v3_req_client 2> /dev/null

rm $EXT_CONF_FILE
unset OPENSSL_CONF

# This will ask for an export password.
# To avoid it, add: -password pass:yourpassword
openssl pkcs12 -export -in $PEM_FILE -inkey $KEY_FILE -out $PFX_FILE

rm -rf $PRIVATE_DIR

THUMBPRINT=`openssl x509 -inform PEM -in $PEM_FILE -fingerprint -noout | \
sed -e 's/\://g' | sed -n 's/^.*=\(.*\)$/\1/p'`

echo "Certificate Thumbprint: $THUMBPRINT"
