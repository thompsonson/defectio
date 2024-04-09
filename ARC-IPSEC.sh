#!/bin/bash

# Function to determine host role
determine_role() {
  HOST_IP=$(hostname -I | awk '{print $1}') # Simplistic IP retrieval; might need adjustment
  if [[ "$HOST_IP" == "137.184.43.207" ]]; then
    echo "moon"
  elif [[ "$HOST_IP" == "164.90.165.138" ]]; then
    echo "sun"
  else
    echo "unknown"
  fi
}

generate_ca(){
  # Generate the CA key and certificate
  ipsec pki --gen --type rsa --size 4096 --outform pem > /etc/swanctl/private/caKey.pem
  ipsec pki --self --ca --lifetime 3650 --in /etc/swanctl/private/caKey.pem --type rsa --dn "C=CH, O=strongSwan, CN=strongSwan Root CA" --outform pem > /etc/swanctl/x509ca/strongswanCert.pem
}

generate_role_cert(){
  HOSTNAME=$1 # "moon" or "sun"
  # Generate the host's key
  ipsec pki --gen --type rsa --size 4096 --outform pem > /etc/swanctl/private/${HOSTNAME}Key.pem
  # Generate and sign the host's certificate
  ipsec pki --pub --in /etc/swanctl/private/${HOSTNAME}Key.pem | ipsec pki --issue --lifetime 1200 --cacert /etc/swanctl/x509ca/strongswanCert.pem --cakey /etc/swanctl/private/caKey.pem --dn "C=CH, O=strongSwan, CN=${HOSTNAME}.strongswan.org" --outform pem > /etc/swanctl/x509/${HOSTNAME}Cert.pem
}

generate_role_config(){
  HOSTNAME=$1 # "moon" or "sun"
  REMOTE_IP=$2 # The IP address of the remote host
  # Assuming REMOTE_IP is directly used as the identifier in the remote section
  cat <<EOF > /etc/swanctl/swanctl.conf
connections {
  host-host {
    remote_addrs = $REMOTE_IP
    local {
      auth = pubkey
      certs = ${HOSTNAME}Cert.pem
    }
    remote {
      auth = pubkey
      id = $REMOTE_IP
    }
    children {
      host-host {
        start_action = trap
      }
    }
  }
}
EOF
}


ROLE=$(determine_role)

# Generic setup for both hosts
mkdir -p /etc/swanctl/{x509ca,x509,private}

generate_ca

# Specific setup based on role
case $ROLE in
  moon)
    generate_role_cert "moon"
    generate_role_config "moon" "164.90.165.138"
    ;;
  sun)
    generate_role_cert "sun"
    generate_role_config "sun" "137.184.43.207"
    ;;
  *)
    echo "Host role could not be determined."
    exit 1
    ;;
esac

# Restart or reload StrongSwan configurations
ipsec restart
