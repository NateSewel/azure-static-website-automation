#!/bin/bash
# create-network.sh - Create VNet and Subnet

set -euo pipefail

# Variables
RESOURCE_GROUP="static-website-rg"
VNET_NAME="website-vnet"
VNET_PREFIX="10.0.0.0/16"
SUBNET_NAME="website-subnet"
SUBNET_PREFIX="10.0.1.0/24"

echo "🌐 Creating Virtual Network and Subnet..."

# Create Virtual Network
az network vnet create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VNET_NAME" \
    --address-prefix "$VNET_PREFIX" \
    --subnet-name "$SUBNET_NAME" \
    --subnet-prefix "$SUBNET_PREFIX" \
    --tags Environment=Production

echo "✅ Virtual Network created:"
echo "   - VNet: $VNET_NAME ($VNET_PREFIX)"
echo "   - Subnet: $SUBNET_NAME ($SUBNET_PREFIX)"

# Display network details
az network vnet show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VNET_NAME" \
    --output table