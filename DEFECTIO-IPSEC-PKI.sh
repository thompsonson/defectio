#!/bin/bash

# Configuration
MOON_IP="137.184.43.207"
SUN_IP="164.90.165.138"
MOON_USER="root"
SUN_USER="root"
CA_CERT="strongswanCert.pem"
MOON_CERT="moonCert.pem"
SUN_CERT="sunCert.pem"
CA_KEY="caKey.pem"
MOON_KEY="moonKey.pem"
SUN_KEY="sunKey.pem"
SWANCTL_DIR_LOCAL="./.pki/etc/swanctl"
SWANCTL_DIR_REMOTE="/etc/swanctl"

# Generic setup for both hosts
mkdir -p $SWANCTL_DIR_LOCAL/{x509ca,x509,private}

# Generate CA
ipsec pki --gen --type rsa --size 4096 --outform pem > $SWANCTL_DIR_LOCAL/private/$CA_KEY
ipsec pki --self --ca --lifetime 3650 --in $SWANCTL_DIR_LOCAL/private/$CA_KEY --type rsa --dn "C=CH, O=strongSwan, CN=strongSwan Root CA" --outform pem > $SWANCTL_DIR_LOCAL/x509ca/$CA_CERT

# Generate moon's certificates
ipsec pki --gen --type rsa --size 4096 --outform pem > $SWANCTL_DIR_LOCAL/private/$MOON_KEY
ipsec pki --pub --in $SWANCTL_DIR_LOCAL/private/$MOON_KEY | ipsec pki --issue --lifetime 1200 --cacert $SWANCTL_DIR_LOCAL/x509ca/$CA_CERT --cakey $SWANCTL_DIR_LOCAL/private/$CA_KEY --dn "C=CH, O=strongSwan, CN=moon.strongswan.org" --outform pem > $SWANCTL_DIR_LOCAL/x509/$MOON_CERT

# Generate sun's certificates
ipsec pki --gen --type rsa --size 4096 --outform pem > $SWANCTL_DIR_LOCAL/private/$SUN_KEY
ipsec pki --pub --in $SWANCTL_DIR_LOCAL/private/$SUN_KEY | ipsec pki --issue --lifetime 1200 --cacert $SWANCTL_DIR_LOCAL/x509ca/$CA_CERT --cakey $SWANCTL_DIR_LOCAL/private/$CA_KEY --dn "C=CH, O=strongSwan, CN=sun.strongswan.org" --outform pem > $SWANCTL_DIR_LOCAL/x509/$SUN_CERT

# Validate CA Certificate
openssl x509 -in $SWANCTL_DIR_LOCAL/x509ca/$CA_CERT -text -noout
if [ $? -ne 0 ]; then
    echo "CA certificate validation failed."
    exit 1
fi

# Ensure remote directory structure
ssh $MOON_USER@$MOON_IP "mkdir -p $SWANCTL_DIR_REMOTE/{x509ca,x509,private}"
ssh $SUN_USER@$SUN_IP "mkdir -p $SWANCTL_DIR_REMOTE/{x509ca,x509,private}"

# Copy CA, moon, and sun certificates to the moon server
scp $SWANCTL_DIR_LOCAL/x509ca/$CA_CERT $MOON_USER@$MOON_IP:$SWANCTL_DIR_REMOTE/x509ca/
scp $SWANCTL_DIR_LOCAL/x509/$MOON_CERT $SWANCTL_DIR_LOCAL/private/$MOON_KEY $MOON_USER@$MOON_IP:$SWANCTL_DIR_REMOTE/x509/
scp $SWANCTL_DIR_LOCAL/private/$MOON_KEY $MOON_USER@$MOON_IP:$SWANCTL_DIR_REMOTE/private/

# Copy CA, moon, and sun certificates to the sun server
scp $SWANCTL_DIR_LOCAL/x509ca/$CA_CERT $SUN_USER@$SUN_IP:$SWANCTL_DIR_REMOTE/x509ca/
scp $SWANCTL_DIR_LOCAL/x509/$SUN_CERT $SWANCTL_DIR_LOCAL/private/$SUN_KEY $SUN_USER@$SUN_IP:$SWANCTL_DIR_REMOTE/x509/
scp $SWANCTL_DIR_LOCAL/private/$SUN_KEY $SUN_USER@$SUN_IP:$SWANCTL_DIR_REMOTE/private/

echo "Certificate deployment complete."
