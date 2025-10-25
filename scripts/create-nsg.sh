#!/bin/bash
# create-nsg.sh - Create Network Security Group with rules

set -euo pipefail

# Variables
RESOURCE_GROUP="static-website-rg"
NSG_NAME="website-nsg"
LOCATION="eastus"

echo "🔒 Creating Network Security Group..."

# Create NSG
az network nsg create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$NSG_NAME" \
    --location "$LOCATION" \
    --tags Environment=Production

# Add rule for HTTP (Port 80)
az network nsg rule create \
    --resource-group "$RESOURCE_GROUP" \
    --nsg-name "$NSG_NAME" \
    --name "AllowHTTP" \
    --priority 100 \
    --source-address-prefixes "*" \
    --source-port-ranges "*" \
    --destination-address-prefixes "*" \
    --destination-port-ranges 80 \
    --access Allow \
    --protocol Tcp \
    --direction Inbound \
    --description "Allow HTTP traffic on port 80"

# Add rule for HTTPS (Port 443)
az network nsg rule create \
    --resource-group "$RESOURCE_GROUP" \
    --nsg-name "$NSG_NAME" \
    --name "AllowHTTPS" \
    --priority 110 \
    --source-address-prefixes "*" \
    --source-port-ranges "*" \
    --destination-address-prefixes "*" \
    --destination-port-ranges 443 \
    --access Allow \
    --protocol Tcp \
    --direction Inbound \
    --description "Allow HTTPS traffic on port 443"

# Add rule for SSH (Port 22) - Restrict to your IP for better security
az network nsg rule create \
    --resource-group "$RESOURCE_GROUP" \
    --nsg-name "$NSG_NAME" \
    --name "AllowSSH" \
    --priority 120 \
    --source-address-prefixes "*" \
    --source-port-ranges "*" \
    --destination-address-prefixes "*" \
    --destination-port-ranges 22 \
    --access Allow \
    --protocol Tcp \
    --direction Inbound \
    --description "Allow SSH access on port 22"

echo "✅ Network Security Group created with rules:"
az network nsg rule list \
    --resource-group "$RESOURCE_GROUP" \
    --nsg-name "$NSG_NAME" \
    --output table