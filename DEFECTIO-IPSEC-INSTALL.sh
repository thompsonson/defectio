#!/bin/bash

# Update package lists to ensure you can access the latest versions
echo "Updating package lists..."
sudo apt-get update

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
