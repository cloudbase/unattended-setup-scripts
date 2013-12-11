#!/bin/bash
set -e

USER_NAME=user$RANDOM

UPN=$USER_NAME@localhost

PFX_FILE=`pwd`/cert.pfx
PFX_PASSWORD=Passw0rd

PEM_FILE=`pwd`/cert.pem
PEM_CA_FILE=`pwd`/ca.pem

CA_DIR=`mktemp -d -t openssl`

pushd .
cd $CA_DIR

mkdir private
chmod 700 private
mkdir certs
mkdir crl

cat > ca.cnf << EOF
[ ca ]
default_ca = mypersonalca

[ mypersonalca ]
dir = $CA_DIR
certs = \$dir/certs
crl_dir = \$dir/crl
database = \$dir/index.txt
new_certs_dir = \$dir/certs
certificate = \$dir/certs/ca.pem
serial = \$dir/serial
crl = \$dir/crl/crl.pem
private_key = \$dir/private/ca.key
RANDFILE = \$dir/private/.rand
x509_extensions = usr_cert
default_days = 3650
default_crl_days= 30
default_md = sha1
preserve = no
policy = mypolicy
x509_extensions = certificate_extensions

[ mypolicy ]
commonName = supplied
stateOrProvinceName = supplied
countryName = supplied
emailAddress = supplied
organizationName = supplied
organizationalUnitName = optional

[ certificate_extensions ]
basicConstraints = CA:false

[ req ]
default_keyfile = $CA_DIR/private/ca.key
default_md = sha1
prompt = no
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid:always,issuer
string_mask = utf8only
basicConstraints = CA:true
distinguished_name = root_ca_distinguished_name
x509_extensions = root_ca_extensions

[ root_ca_distinguished_name ]
commonName = WinRM CA
stateOrProvinceName = Timis
countryName = RO
emailAddress = info@cloudbase.it
organizationName = WinRM CA

[ root_ca_extensions ]
basicConstraints = CA:true

[v3_req_server]
extendedKeyUsage = serverAuth
EOF

cat > openssl.cnf << EOF
distinguished_name  = req_distinguished_name
[req_distinguished_name]
[v3_req]
[v3_req_server]
extendedKeyUsage = serverAuth
[v3_ca]
EOF

touch index.txt
echo 01 > serial

export OPENSSL_CONF=ca.cnf
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -out certs/ca.pem -outform PEM -keyout private/ca.key

export OPENSSL_CONF=openssl.cnf
openssl req -newkey rsa:2048 -nodes -sha1 -keyout private/cert.key -keyform PEM -out certs/cert.req -outform PEM -subj \
"/C=US/ST=Timis/L=Timisoara/emailAddress=info@cloudbase.it/organizationName=IT/CN=$USER_NAME"

EXT_CONF_FILE=`mktemp -t openssl`

cat > $EXT_CONF_FILE << EOF
[v3_req_client]
extendedKeyUsage = clientAuth
subjectAltName = otherName:1.3.6.1.4.1.311.20.2.3;UTF8:$UPN
EOF

export OPENSSL_CONF=ca.cnf
openssl ca -batch -notext -in certs/cert.req -out certs/cert.pem -extensions v3_req_client -extfile $EXT_CONF_FILE

rm $EXT_CONF_FILE

# Export the certificate, including the CA chain, into cert.pfx
openssl pkcs12 -export -in certs/cert.pem -inkey private/cert.key -chain -CAfile certs/ca.pem -out $PFX_FILE -password pass:$PFX_PASSWORD

cp certs/cert.pem $PEM_FILE
cp certs/ca.pem $PEM_CA_FILE

popd
rm -rf $CA_DIR

