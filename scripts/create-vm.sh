#!/bin/bash
################################################################################
# create-vm-simple.sh - Create VM without cloud-init (Manual NGINX setup)
# Description: Creates VM first, then installs NGINX via SSH
# This avoids cloud-init timeout issues
################################################################################

set -euo pipefail

# Variables
RESOURCE_GROUP="${RESOURCE_GROUP:-static-website-rg}"
VM_NAME="${VM_NAME:-website-vm}"
NIC_NAME="${NIC_NAME:-website-nic}"
LOCATION="${LOCATION:-eastus}"
VM_SIZE="Standard_B1s"  # Explicitly set to avoid defaults
IMAGE="Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest"
ADMIN_USERNAME="${ADMIN_USERNAME:-azureuser}"
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/azure_website_key}"
PUBLIC_IP_NAME="${PUBLIC_IP_NAME:-website-public-ip}"

echo "🖥️  Creating Virtual Machine (without cloud-init)..."
echo "   This approach creates VM first, then installs NGINX via SSH"
echo ""

# Check if SSH key exists
if [ ! -f "${SSH_KEY_PATH}.pub" ]; then
    echo "❌ Error: SSH public key not found at ${SSH_KEY_PATH}.pub"
    echo "   Run: ssh-keygen -t rsa -b 4096 -f $SSH_KEY_PATH -N ''"
    exit 1
fi

# Check if NIC exists
if ! az network nic show --resource-group "$RESOURCE_GROUP" --name "$NIC_NAME" &>/dev/null; then
    echo "❌ Error: Network Interface '$NIC_NAME' not found"
    echo "   Create it first with: ./scripts/create-nic.sh"
    exit 1
fi

# Create the VM WITHOUT cloud-init
echo "🔨 Creating Virtual Machine..."
echo "   Resource Group: $RESOURCE_GROUP"
echo "   VM Name: $VM_NAME"
echo "   VM Size: $VM_SIZE"
echo "   Location: $LOCATION"
echo ""

az vm create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --location "$LOCATION" \
    --nics "$NIC_NAME" \
    --size "$VM_SIZE" \
    --image "$IMAGE" \
    --admin-username "$ADMIN_USERNAME" \
    --ssh-key-values "@${SSH_KEY_PATH}.pub" \
    --public-ip-address "" \
    --output none

echo "✅ Virtual Machine created successfully!"
echo ""

# Get public IP
echo "🔍 Getting Public IP address..."
PUBLIC_IP=$(az network public-ip show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$PUBLIC_IP_NAME" \
    --query ipAddress \
    --output tsv 2>/dev/null || echo "")

if [ -z "$PUBLIC_IP" ]; then
    echo "⚠️  Could not retrieve public IP. Checking VM details..."
    PUBLIC_IP=$(az vm show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$VM_NAME" \
        --show-details \
        --query publicIps \
        --output tsv)
fi

echo "✅ Public IP: $PUBLIC_IP"
echo ""

# Wait for VM to be fully ready
echo "⏳ Waiting for VM to be accessible via SSH (30 seconds)..."
sleep 30

# Test SSH connectivity
echo "🔍 Testing SSH connectivity..."
MAX_RETRIES=10
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if ssh -i "$SSH_KEY_PATH" \
           -o StrictHostKeyChecking=no \
           -o ConnectTimeout=10 \
           -o BatchMode=yes \
           "$ADMIN_USERNAME@$PUBLIC_IP" \
           "echo 'SSH connection successful'" &>/dev/null; then
        echo "✅ SSH connection established!"
        break
    fi
    
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "   Attempt $RETRY_COUNT/$MAX_RETRIES - Retrying in 10 seconds..."
    sleep 10
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "⚠️  Could not establish SSH connection. VM might still be initializing."
    echo "   Try manually: ssh -i $SSH_KEY_PATH $ADMIN_USERNAME@$PUBLIC_IP"
    exit 0
fi

echo ""
echo "🚀 Installing and configuring NGINX via SSH..."

# Install NGINX and configure website
ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$ADMIN_USERNAME@$PUBLIC_IP" << 'ENDSSH'
    set -e
    
    echo "📦 Updating package lists..."
    sudo apt-get update -qq
    
    echo "📥 Installing NGINX..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nginx
    
    echo "🔧 Configuring firewall..."
    sudo ufw allow 'Nginx Full'
    sudo ufw allow OpenSSH
    echo "y" | sudo ufw enable || true
    
    echo "📝 Creating website..."
    sudo tee /var/www/html/index.html > /dev/null << 'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Azure Static Website</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .container {
            background: white;
            border-radius: 20px;
            padding: 60px;
            max-width: 800px;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
            text-align: center;
        }
        h1 {
            color: #667eea;
            font-size: 3em;
            margin-bottom: 20px;
        }
        .icon { font-size: 5em; margin-bottom: 20px; }
        p {
            color: #666;
            font-size: 1.2em;
            line-height: 1.6;
            margin: 15px 0;
        }
        .status {
            background: #28a745;
            color: white;
            padding: 10px 20px;
            border-radius: 20px;
            display: inline-block;
            margin: 20px 0;
        }
        code {
            background: #f4f4f4;
            padding: 2px 8px;
            border-radius: 4px;
            color: #667eea;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="icon">🚀</div>
        <h1>Deployment Successful!</h1>
        <div class="status">● Online</div>
        <p>Your Azure static website is now live!</p>
        <p><strong>Server:</strong> NGINX on Ubuntu 22.04 LTS</p>
        <p><strong>Deployed via:</strong> Azure CLI</p>
        <p style="margin-top: 30px; color: #999;">
            Replace this file at <code>/var/www/html/index.html</code>
        </p>
    </div>
</body>
</html>
HTMLEOF
    
    echo "🔧 Configuring NGINX..."
    sudo tee /etc/nginx/sites-available/default > /dev/null << 'NGINXCONF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    root /var/www/html;
    index index.html index.htm;
    
    server_name _;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml text/javascript;
}
NGINXCONF
    
    echo "🔄 Setting permissions..."
    sudo chown -R www-data:www-data /var/www/html
    sudo chmod -R 755 /var/www/html
    
    echo "🔄 Restarting NGINX..."
    sudo systemctl restart nginx
    sudo systemctl enable nginx
    
    echo "✅ NGINX installation and configuration complete!"
ENDSSH

echo ""
echo "════════════════════════════════════════════════════════════"
echo "✅ VM Deployment and Configuration Complete!"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "🌐 Public IP:     $PUBLIC_IP"
echo "🔑 SSH Command:   ssh -i $SSH_KEY_PATH $ADMIN_USERNAME@$PUBLIC_IP"
echo "🌍 Website URL:   http://$PUBLIC_IP"
echo ""
echo "🧪 Testing website accessibility..."

sleep 5

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$PUBLIC_IP" 2>/dev/null || echo "000")

if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Website is accessible! HTTP Status: $HTTP_CODE"
else
    echo "⚠️  Website returned HTTP $HTTP_CODE (may need a moment)"
fi

echo ""
echo "════════════════════════════════════════════════════════════"