#!/bin/bash

# Install StrongSwan, the swanctl utility, and commonly used plugins
echo "Installing StrongSwan, swanctl, and required plugins..."
sudo apt-get install -y strongswan strongswan-pki libstrongswan-extra-plugins strongswan-swanctl

# Install additional utilities that might be useful
echo "Installing additional utilities..."
sudo apt-get install -y charon-systemd libcharon-extra-plugins libcharon-standard-plugins

# Verify installation
echo "Verifying installation..."
ipsec version
swanctl --version

echo "StrongSwan and swanctl installation completed successfully."

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

  echo "Config has been generated."

  # Now that config is generated, validate the certificates.
  echo "Validating certificates..."
  CERT_PATH="/etc/swanctl/x509"
  PRIV_KEY_PATH="/etc/swanctl/private"
  CA_CERT_PATH="/etc/swanctl/x509ca"

  # Validate the CA certificate
  if ! openssl x509 -in $CA_CERT_PATH/strongswanCert.pem -noout > /dev/null 2>&1; then
    echo "CA certificate validation failed."
    exit 1
  else
    echo "CA certificate validation succeeded."
  fi

  # Validate the server certificate
  if ! openssl x509 -in $CERT_PATH/${HOSTNAME}Cert.pem -noout > /dev/null 2>&1; then
    echo "${HOSTNAME} certificate validation failed."
    exit 1
  else
    echo "${HOSTNAME} certificate validation succeeded."
  fi

  # Validate the server private key
  if ! openssl rsa -in $PRIV_KEY_PATH/${HOSTNAME}Key.pem -check -noout > /dev/null 2>&1; then
    echo "${HOSTNAME} private key validation failed."
    exit 1
  else
    echo "${HOSTNAME} private key validation succeeded."
  fi

  # Check the certificate matches the private key
  CERT_MODULUS=$(openssl x509 -noout -modulus -in $CERT_PATH/${HOSTNAME}Cert.pem | openssl md5)
  KEY_MODULUS=$(openssl rsa -noout -modulus -in $PRIV_KEY_PATH/${HOSTNAME}Key.pem | openssl md5)

  if [ "$CERT_MODULUS" != "$KEY_MODULUS" ]; then
    echo "The private key does not match the certificate for ${HOSTNAME}."
    exit 1
  else
    echo "Private key matches the certificate for ${HOSTNAME}."
  fi
  echo "All validations passed for ${HOSTNAME}."
}

verify_firewall() {
    echo "Verifying firewall configuration for IPsec..."

    # Check for iptables or ufw
    if command -v ufw >/dev/null 2>&1; then
        echo "Using ufw to check firewall rules..."
        if ! sudo ufw status | grep -qw "500/udp"; then
            echo "Firewall rule for UDP port 500 is missing."
            exit 1
        fi
        if ! sudo ufw status | grep -qw "4500/udp"; then
            echo "Firewall rule for UDP port 4500 is missing."
            exit 1
        fi
    elif command -v iptables >/dev/null 2>&1; then
        echo "Using iptables to check firewall rules..."
        if ! sudo iptables -L -v -n | grep -qw "udp" | grep -qw "dpt:500"; then
            echo "Firewall rule for UDP port 500 is missing."
            exit 1
        fi
        if ! sudo iptables -L -v -n | grep -qw "udp" | grep -qw "dpt:4500"; then
            echo "Firewall rule for UDP port 4500 is missing."
            exit 1
        fi
    else
        echo "No recognized firewall tool found (checked for ufw and iptables)."
        exit 1
    fi

    echo "Firewall configuration for IPsec is correct."
}


ROLE=$(determine_role)

# Generic setup for both hosts
mkdir -p /etc/swanctl/{x509ca,x509,private}

# Specific setup based on role
case $ROLE in
  moon)
    generate_role_config "moon" "164.90.165.138"
    ;;
  sun)
    generate_role_config "sun" "137.184.43.207"
    ;;
  *)
    echo "Host role could not be determined."
    exit 1
    ;;
esac

verify_firewall

# Apply the configuration and reload StrongSwan
swanctl --load-all
swanctl --reload-settings
swanctl --initiate --child host-host
