#!/bin/bash
# create-vm.sh - Create Ubuntu VM with NGINX

set -euo pipefail

# Variables
RESOURCE_GROUP="static-website-rg"
VM_NAME="website-vm"
NIC_NAME="website-nic"
LOCATION="eastus"
VM_SIZE="Standard_B1s"  # Cost-effective for static websites
IMAGE="Ubuntu2204"  # Ubuntu 22.04 LTS
ADMIN_USERNAME="azureuser"
SSH_KEY_PATH="$HOME/.ssh/azure_website_key.pub"

echo "🖥️  Creating Virtual Machine with NGINX..."

# Cloud-init script to install and configure NGINX
CLOUD_INIT=$(cat <<'EOF'
#cloud-config
package_update: true
package_upgrade: true
packages:
  - nginx
  - git
  - curl

runcmd:
  # Start and enable NGINX
  - systemctl start nginx
  - systemctl enable nginx
  
  # Create a temporary welcome page
  - |
    cat > /var/www/html/index.html <<'HTML'
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Azure Static Website - Deployment Successful</title>
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body {
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                min-height: 100vh;
                display: flex;
                align-items: center;
                justify-content: center;
                color: white;
            }
            .container {
                text-align: center;
                padding: 40px;
                background: rgba(255, 255, 255, 0.1);
                border-radius: 20px;
                backdrop-filter: blur(10px);
                box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
                max-width: 600px;
            }
            h1 {
                font-size: 3em;
                margin-bottom: 20px;
                animation: fadeIn 1s ease-in;
            }
            p {
                font-size: 1.2em;
                margin: 15px 0;
                line-height: 1.6;
            }
            .success-icon {
                font-size: 5em;
                margin-bottom: 20px;
                animation: bounce 2s infinite;
            }
            @keyframes fadeIn {
                from { opacity: 0; transform: translateY(-20px); }
                to { opacity: 1; transform: translateY(0); }
            }
            @keyframes bounce {
                0%, 100% { transform: translateY(0); }
                50% { transform: translateY(-20px); }
            }
            .info {
                background: rgba(255, 255, 255, 0.2);
                padding: 20px;
                border-radius: 10px;
                margin-top: 30px;
            }
            code {
                background: rgba(0, 0, 0, 0.3);
                padding: 5px 10px;
                border-radius: 5px;
                font-family: 'Courier New', monospace;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="success-icon">✅</div>
            <h1>Deployment Successful!</h1>
            <p>Your Azure static website is now live and running on NGINX.</p>
            <div class="info">
                <p><strong>Server:</strong> NGINX on Ubuntu 22.04 LTS</p>
                <p><strong>Status:</strong> <span style="color: #90EE90;">● Online</span></p>
                <p><strong>Deployment:</strong> Azure CLI + Cloud-Init</p>
            </div>
            <p style="margin-top: 30px; font-size: 0.9em;">
                Replace this page with your custom HTML in <code>/var/www/html/</code>
            </p>
        </div>
    </body>
    </html>
    HTML
  
  # Set proper permissions
  - chown -R www-data:www-data /var/www/html
  - chmod -R 755 /var/www/html
  
  # Configure NGINX for better performance
  - |
    cat > /etc/nginx/sites-available/default <<'NGINX'
    server {
        listen 80 default_server;
        listen [::]:80 default_server;
        
        root /var/www/html;
        index index.html index.htm;
        
        server_name _;
        
        location / {
            try_files $uri $uri/ =404;
        }
        
        # Enable gzip compression
        gzip on;
        gzip_vary on;
        gzip_types text/plain text/css application/json application/javascript text/xml application/xml text/javascript;
    }
    NGINX
  
  - systemctl restart nginx

final_message: "NGINX web server is configured and running!"
EOF
)

# Save cloud-init to temporary file
echo "$CLOUD_INIT" > /tmp/cloud-init.txt

# Create VM
az vm create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --location "$LOCATION" \
    --nics "$NIC_NAME" \
    --size "$VM_SIZE" \
    --image "$IMAGE" \
    --admin-username "$ADMIN_USERNAME" \
    --ssh-key-values "@$SSH_KEY_PATH" \
    --custom-data /tmp/cloud-init.txt \
    --tags Environment=Production Role=WebServer

# Clean up temp file
rm /tmp/cloud-init.txt

echo "✅ Virtual Machine created successfully!"
echo ""
echo "📊 VM Details:"
az vm show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --show-details \
    --output table

# Get public IP
PUBLIC_IP=$(az network public-ip show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$PUBLIC_IP_NAME" \
    --query ipAddress \
    --output tsv)

echo ""
echo "🌐 Website URL: http://$PUBLIC_IP"
echo "🔑 SSH Access: ssh -i $HOME/.ssh/azure_website_key $ADMIN_USERNAME@$PUBLIC_IP"
echo ""
echo "⏳ Please wait 2-3 minutes for cloud-init to complete NGINX installation..."