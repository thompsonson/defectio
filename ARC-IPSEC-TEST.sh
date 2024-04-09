#!/bin/bash

# Automatically determine the host's IP
HOST_IP=$(hostname -I | awk '{print $1}')

# Define the IP addresses for moon and sun
MOON_IP="137.184.43.207"
SUN_IP="164.90.165.138"

# Check which host it is and set REMOTE_IP accordingly
if [ "$HOST_IP" == "$MOON_IP" ]; then
    REMOTE_IP=$SUN_IP
elif [ "$HOST_IP" == "$SUN_IP" ]; then
    REMOTE_IP=$MOON_IP
else
    echo "Unknown host IP. Please ensure this script runs on a designated moon or sun host."
    exit 1
fi

# Continue with the IPsec status check and ping test as before
echo "Checking IPsec tunnel status..."
ipsec status | grep "$REMOTE_IP" &> /dev/null

if [ $? -eq 0 ]; then
    echo "IPsec tunnel to $REMOTE_IP is up."
else
    echo "IPsec tunnel to $REMOTE_IP is down. Attempting to start it..."
    ipsec up host-host
    sleep 5 # Wait a bit for the connection to establish
    ipsec status | grep "$REMOTE_IP" &> /dev/null
    if [ $? -eq 0 ]; then
        echo "IPsec tunnel to $REMOTE_IP is now up."
    else
        echo "Failed to establish IPsec tunnel to $REMOTE_IP."
        exit 1
    fi
fi

# Perform a ping test
echo "Performing ping test to $REMOTE_IP..."
ping -c 4 $REMOTE_IP

if [ $? -eq 0 ]; then
    echo "Ping test successful. Connectivity through the IPsec tunnel is verified."
else
    echo "Ping test failed. Check the IPsec tunnel and network configuration."
fi
