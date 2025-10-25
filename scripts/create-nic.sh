#!/bin/bash
# create-nic.sh - Create Network Interface

set -euo pipefail

# Variables
RESOURCE_GROUP="static-website-rg"
NIC_NAME="website-nic"
VNET_NAME="website-vnet"
SUBNET_NAME="website-subnet"
NSG_NAME="website-nsg"
PUBLIC_IP_NAME="website-public-ip"
LOCATION="eastus"

echo "🔌 Creating Network Interface..."

# Create NIC and associate with subnet, NSG, and public IP
az network nic create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$NIC_NAME" \
    --location "$LOCATION" \
    --vnet-name "$VNET_NAME" \
    --subnet "$SUBNET_NAME" \
    --network-security-group "$NSG_NAME" \
    --public-ip-address "$PUBLIC_IP_NAME" \
    --tags Environment=Production

echo "✅ Network Interface created and configured:"
az network nic show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$NIC_NAME" \
    --output table