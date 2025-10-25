#!/bin/bash
# create-resource-group.sh - Create Azure Resource Group

set -euo pipefail

# Variables
RESOURCE_GROUP="static-website-rg"
LOCATION="eastus"

echo "📦 Creating Resource Group..."

# Create resource group
az group create \
    --name "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --tags Environment=Production Project=StaticWebsite Owner=DevOps

# Verify creation
if az group show --name "$RESOURCE_GROUP" &>/dev/null; then
    echo "✅ Resource Group '$RESOURCE_GROUP' created successfully in $LOCATION"
    az group show --name "$RESOURCE_GROUP" --output table
else
    echo "❌ Failed to create Resource Group"
    exit 1
fi