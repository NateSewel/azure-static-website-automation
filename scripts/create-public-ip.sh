#!/bin/bash
# create-public-ip.sh - Create Static Public IP

set -euo pipefail

# Variables
RESOURCE_GROUP="static-website-rg"
PUBLIC_IP_NAME="website-public-ip"
LOCATION="eastus"
DNS_NAME="mystaticwebsite$RANDOM"  # Must be globally unique

echo "🌍 Creating Public IP Address..."

# Create static public IP with DNS name
az network public-ip create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$PUBLIC_IP_NAME" \
    --location "$LOCATION" \
    --allocation-method Static \
    --sku Standard \
    --dns-name "$DNS_NAME" \
    --tags Environment=Production

# Get the public IP address
PUBLIC_IP=$(az network public-ip show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$PUBLIC_IP_NAME" \
    --query ipAddress \
    --output tsv)

FQDN=$(az network public-ip show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$PUBLIC_IP_NAME" \
    --query dnsSettings.fqdn \
    --output tsv)

echo "✅ Public IP created:"
echo "   - IP Address: $PUBLIC_IP"
echo "   - FQDN: $FQDN"
echo ""
echo "🌐 Your website will be accessible at: http://$PUBLIC_IP"