#!/bin/bash

# ===EDIT ME===
WAZUH_MAC="3c:52:82:98:f7:ef" # HP mac address example
# =============

# Destination IP address you want to check the connection for
DEST_IP="8.8.8.8"

# Determine the local IP address used to connect to DEST_IP
LOCAL_IP=$(ip route get $DEST_IP | awk '{print $7; exit}')

# Extract the first octet to determine the class
FIRST_OCTET=$(echo $LOCAL_IP | cut -d '.' -f 1)

# Initialize subnet mask
SUBNET_MASK=""

# Determine the network class and subnet mask
if (( FIRST_OCTET >= 1 && FIRST_OCTET <= 126 )); then
  # Class A
  SUBNET_MASK="8"
elif (( FIRST_OCTET >= 128 && FIRST_OCTET <= 191 )); then
  # Class B
  SUBNET_MASK="16"
elif (( FIRST_OCTET >= 192 && FIRST_OCTET <= 223 )); then
  # Class C
  SUBNET_MASK="24"
else
  echo "IP address does not belong to class A, B, or C."
  exit 1
fi

# Construct the SUBNET variable based on the determined class
if [[ $SUBNET_MASK != "" ]]; then
  case $SUBNET_MASK in
  8)
    SUBNET=$(echo $LOCAL_IP | awk -F'.' '{print $1".0.0.0/"'$SUBNET_MASK'}')
    ;;
  16)
    SUBNET=$(echo $LOCAL_IP | awk -F'.' '{print $1"."$2".0.0/"'$SUBNET_MASK'}')
    ;;
  24)
    SUBNET=$(echo $LOCAL_IP | awk -F'.' '{print $1"."$2"."$3".0/"'$SUBNET_MASK'}')
    ;;
  esac
fi

LOCAL_DNS=$(echo $LOCAL_IP | awk -F'.' '{print $1"."$2"."$3".1"}')
GATEWAY=$LOCAL_DNS

echo "Local IP address used for connection to $DEST_IP: $LOCAL_IP"
echo "Assumed Local DNS IP: $LOCAL_DNS"
echo "Subnet: $SUBNET"
echo "Building container. Please wait..."
docker stop wazuh_container && docker rm wazuh_container
docker build -t wazuh:latest .
docker network rm wazuh_network
docker network create -d macvlan --subnet=$SUBNET --gateway=$GATEWAY -o parent=enp3s0 wazuh_network
docker run -dit --privileged --name wazuh_container --network wazuh_network --cap-add=NET_ADMIN --mac-address=$WAZUH_MAC wazuh
