#!/bin/bash
set -e

PEM_FILE=winrm_client_cert.pem
IMAGE_NAME="your windows image"
KEY=key1
INSTANCE_NAME=vm1
FLAVOR=2

# Split the base64 encoded certificate in chunks of 255 chars
# to overcome Nova's custom metadata length limit
declare -a CERT=(`openssl x509 -inform pem -in "$PEM_FILE" -outform der | base64 -w 0 |sed -r 's/(.{255})/\1\n/g'`)

nova boot  --flavor $FLAVOR --image "$IMAGE_NAME" --key-name $KEY $INSTANCE_NAME \
--meta admin_cert0="${CERT[0]}" \
--meta admin_cert1="${CERT[1]}" \
--meta admin_cert2="${CERT[2]}" \
--meta admin_cert3="${CERT[3]}" \
--meta admin_cert4="${CERT[4]}"
