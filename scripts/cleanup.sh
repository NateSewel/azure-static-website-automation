#!/bin/bash
################################################################################
# Azure Resource Cleanup Script
# Description: Safely delete all Azure resources created for static website
# Author: DevOps Team
# Version: 1.0.0
################################################################################

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
RESOURCE_GROUP="${RESOURCE_GROUP:-static-website-rg}"

echo -e "${YELLOW}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║              Azure Resource Cleanup Script                    ║
║                                                               ║
║        ⚠️  WARNING: This will DELETE all resources! ⚠️        ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check if resource group exists
if ! az group show --name "$RESOURCE_GROUP" &> /dev/null; then
    echo -e "${GREEN}✅ Resource group '$RESOURCE_GROUP' does not exist. Nothing to clean up.${NC}"
    exit 0
fi

# Display resources to be deleted
echo -e "${YELLOW}📋 Resources in '$RESOURCE_GROUP' that will be DELETED:${NC}"
echo ""
az resource list --resource-group "$RESOURCE_GROUP" --output table
echo ""

# Confirmation prompt
echo -e "${RED}⚠️  This action CANNOT be undone!${NC}"
echo -e "${YELLOW}All resources in '$RESOURCE_GROUP' will be permanently deleted.${NC}"
echo ""
read -p "Type 'DELETE' to confirm deletion: " CONFIRMATION

if [ "$CONFIRMATION" != "DELETE" ]; then
    echo -e "${GREEN}✅ Cleanup cancelled. No resources were deleted.${NC}"
    exit 0
fi

# Delete resource group
echo ""
echo -e "${YELLOW}🗑️  Deleting resource group: $RESOURCE_GROUP${NC}"
echo "This may take several minutes..."

az group delete \
    --name "$RESOURCE_GROUP" \
    --yes \
    --no-wait

echo ""
echo -e "${GREEN}✅ Deletion initiated successfully!${NC}"
echo ""
echo "The resource group is being deleted in the background."
echo "To check deletion status, run:"
echo "  az group show --name $RESOURCE_GROUP"
echo ""
echo "When deletion is complete, the command will return an error."

# Optional: Wait for deletion to complete
read -p "Wait for deletion to complete? (y/N): " WAIT_CHOICE

if [[ "$WAIT_CHOICE" =~ ^[Yy]$ ]]; then
    echo ""
    echo "⏳ Waiting for deletion to complete..."
    
    while az group show --name "$RESOURCE_GROUP" &> /dev/null; do
        echo -n "."
        sleep 10
    done
    
    echo ""
    echo -e "${GREEN}✅ Resource group '$RESOURCE_GROUP' has been completely deleted!${NC}"
    echo ""
    echo "💰 All resources have been removed. You will no longer be charged for these resources."
else
    echo ""
    echo -e "${GREEN}✅ Cleanup script completed. Deletion is running in background.${NC}"
fi