#!/bin/bash
# deploy-website.sh - Deploy custom static website

set -euo pipefail

# Variables
RESOURCE_GROUP="static-website-rg"
PUBLIC_IP_NAME="website-public-ip"
ADMIN_USERNAME="azureuser"
SSH_KEY_PATH="$HOME/.ssh/azure_website_key"
WEBSITE_DIR="./website"  # Local directory with your website files

echo "🚀 Deploying custom website..."

# Get public IP
PUBLIC_IP=$(az network public-ip show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$PUBLIC_IP_NAME" \
    --query ipAddress \
    --output tsv)

echo "📡 Target server: $PUBLIC_IP"

# Wait for VM to be ready
echo "⏳ Waiting for VM to be ready..."
sleep 30

# Test SSH connectivity
echo "🔍 Testing SSH connection..."
ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
    "$ADMIN_USERNAME@$PUBLIC_IP" "echo 'SSH connection successful'"

# Create website directory if it doesn't exist locally
if [ ! -d "$WEBSITE_DIR" ]; then
    echo "📁 Website directory not found. Creating sample website..."
    mkdir -p "$WEBSITE_DIR"
    # Sample website will be created in next step
fi

# Copy website files to server
echo "📤 Uploading website files..."
scp -i "$SSH_KEY_PATH" -r "$WEBSITE_DIR"/* \
    "$ADMIN_USERNAME@$PUBLIC_IP:/tmp/"

# Move files to web root and set permissions
ssh -i "$SSH_KEY_PATH" "$ADMIN_USERNAME@$PUBLIC_IP" << 'ENDSSH'
    sudo rm -rf /var/www/html/*
    sudo mv /tmp/* /var/www/html/ 2>/dev/null || true
    sudo chown -R www-data:www-data /var/www/html
    sudo chmod -R 755 /var/www/html
    sudo systemctl restart nginx
    echo "✅ Website deployed successfully!"
ENDSSH

echo ""
echo "🎉 Deployment complete!"
echo "🌐 Visit your website: http://$PUBLIC_IP"