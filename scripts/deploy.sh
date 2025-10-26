#!/bin/bash
################################################################################
# Azure Static Website Deployment - Master Script (UPGRADED)
# Description: Complete automation for deploying a static website on Azure
# Version: 2.0.0 - Fixed cloud-init timeout issues
# Author: DevOps Team
################################################################################

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; exit 1; }
log_step() { echo -e "${PURPLE}▶️  $1${NC}"; }

# Default configuration
RESOURCE_GROUP="${RESOURCE_GROUP:-static-website-rg}"
LOCATION="${LOCATION:-eastus}"
VNET_NAME="${VNET_NAME:-website-vnet}"
SUBNET_NAME="${SUBNET_NAME:-website-subnet}"
NSG_NAME="${NSG_NAME:-website-nsg}"
PUBLIC_IP_NAME="${PUBLIC_IP_NAME:-website-public-ip}"
NIC_NAME="${NIC_NAME:-website-nic}"
VM_NAME="${VM_NAME:-website-vm}"
VM_SIZE="${VM_SIZE:-Standard_B1s}"
ADMIN_USERNAME="${ADMIN_USERNAME:-azureuser}"
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/azure_website_key}"
DNS_NAME="staticwebsite${RANDOM}"

# VM Image - explicit to avoid GitHub lookups
VM_IMAGE="Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest"

# Banner
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║        Azure Static Website Deployment Automation            ║
║                      Version 2.0                              ║
║                                                               ║
║     Deploying: VNet → NSG → VM → NGINX → Static Website     ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF

echo ""
log_info "Starting deployment with the following configuration:"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  Location: $LOCATION"
echo "  VM Size: $VM_SIZE"
echo "  Admin User: $ADMIN_USERNAME"
echo ""

# Function to check if Azure CLI is installed
check_azure_cli() {
    log_step "Checking Azure CLI installation..."
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI is not installed. Please install it first."
    fi
    log_success "Azure CLI found: $(az version --query '\"azure-cli\"' -o tsv)"
}

# Function to check if logged into Azure
check_azure_login() {
    log_step "Checking Azure authentication..."
    if ! az account show &> /dev/null; then
        log_warning "Not logged into Azure. Initiating login..."
        az login
    fi
    
    SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)
    log_success "Authenticated to Azure subscription: $SUBSCRIPTION_NAME"
}

# Function to generate SSH key if not exists
generate_ssh_key() {
    log_step "Checking SSH key..."
    if [ ! -f "$SSH_KEY_PATH" ]; then
        log_warning "SSH key not found. Generating new key pair..."
        ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N "" -C "azure-website-deployment"
        log_success "SSH key generated at $SSH_KEY_PATH"
    else
        log_success "SSH key already exists at $SSH_KEY_PATH"
    fi
}

# Function to create resource group
create_resource_group() {
    log_step "Creating Resource Group: $RESOURCE_GROUP..."
    
    if az group show --name "$RESOURCE_GROUP" &> /dev/null; then
        log_warning "Resource Group already exists. Skipping creation."
    else
        az group create \
            --name "$RESOURCE_GROUP" \
            --location "$LOCATION" \
            --tags Environment=Production Project=StaticWebsite \
            --output none
        log_success "Resource Group created: $RESOURCE_GROUP"
    fi
}

# Function to create virtual network
create_virtual_network() {
    log_step "Creating Virtual Network: $VNET_NAME..."
    
    if az network vnet show --resource-group "$RESOURCE_GROUP" --name "$VNET_NAME" &> /dev/null; then
        log_warning "Virtual Network already exists. Skipping creation."
    else
        az network vnet create \
            --resource-group "$RESOURCE_GROUP" \
            --name "$VNET_NAME" \
            --address-prefix "10.0.0.0/16" \
            --subnet-name "$SUBNET_NAME" \
            --subnet-prefix "10.0.1.0/24" \
            --output none
        
        log_success "Virtual Network created: $VNET_NAME (10.0.0.0/16)"
        log_success "Subnet created: $SUBNET_NAME (10.0.1.0/24)"
    fi
}

# Function to create network security group
create_nsg() {
    log_step "Creating Network Security Group: $NSG_NAME..."
    
    if az network nsg show --resource-group "$RESOURCE_GROUP" --name "$NSG_NAME" &> /dev/null; then
        log_warning "NSG already exists. Skipping creation."
    else
        az network nsg create \
            --resource-group "$RESOURCE_GROUP" \
            --name "$NSG_NAME" \
            --location "$LOCATION" \
            --output none
        
        log_info "Adding NSG rules for HTTP, HTTPS, and SSH..."
        
        # HTTP
        az network nsg rule create \
            --resource-group "$RESOURCE_GROUP" \
            --nsg-name "$NSG_NAME" \
            --name "AllowHTTP" \
            --priority 100 \
            --source-address-prefixes "*" \
            --destination-port-ranges 80 \
            --access Allow \
            --protocol Tcp \
            --direction Inbound \
            --output none
        
        # HTTPS
        az network nsg rule create \
            --resource-group "$RESOURCE_GROUP" \
            --nsg-name "$NSG_NAME" \
            --name "AllowHTTPS" \
            --priority 110 \
            --destination-port-ranges 443 \
            --access Allow \
            --protocol Tcp \
            --direction Inbound \
            --output none
        
        # SSH
        az network nsg rule create \
            --resource-group "$RESOURCE_GROUP" \
            --nsg-name "$NSG_NAME" \
            --name "AllowSSH" \
            --priority 120 \
            --destination-port-ranges 22 \
            --access Allow \
            --protocol Tcp \
            --direction Inbound \
            --output none
        
        log_success "Network Security Group created with HTTP, HTTPS, and SSH rules"
    fi
}

# Function to create public IP
create_public_ip() {
    log_step "Creating Public IP Address: $PUBLIC_IP_NAME..."
    
    if az network public-ip show --resource-group "$RESOURCE_GROUP" --name "$PUBLIC_IP_NAME" &> /dev/null; then
        log_warning "Public IP already exists. Skipping creation."
        PUBLIC_IP=$(az network public-ip show \
            --resource-group "$RESOURCE_GROUP" \
            --name "$PUBLIC_IP_NAME" \
            --query ipAddress \
            --output tsv)
    else
        az network public-ip create \
            --resource-group "$RESOURCE_GROUP" \
            --name "$PUBLIC_IP_NAME" \
            --location "$LOCATION" \
            --allocation-method Static \
            --sku Standard \
            --dns-name "$DNS_NAME" \
            --output none
        
        PUBLIC_IP=$(az network public-ip show \
            --resource-group "$RESOURCE_GROUP" \
            --name "$PUBLIC_IP_NAME" \
            --query ipAddress \
            --output tsv)
        
        log_success "Public IP created: $PUBLIC_IP"
    fi
}

# Function to create network interface
create_network_interface() {
    log_step "Creating Network Interface: $NIC_NAME..."
    
    if az network nic show --resource-group "$RESOURCE_GROUP" --name "$NIC_NAME" &> /dev/null; then
        log_warning "Network Interface already exists. Skipping creation."
    else
        az network nic create \
            --resource-group "$RESOURCE_GROUP" \
            --name "$NIC_NAME" \
            --location "$LOCATION" \
            --vnet-name "$VNET_NAME" \
            --subnet "$SUBNET_NAME" \
            --network-security-group "$NSG_NAME" \
            --public-ip-address "$PUBLIC_IP_NAME" \
            --output none
        
        log_success "Network Interface created and configured"
    fi
}

# Function to create VM WITHOUT cloud-init
create_virtual_machine() {
    log_step "Creating Virtual Machine: $VM_NAME..."
    
    if az vm show --resource-group "$RESOURCE_GROUP" --name "$VM_NAME" &> /dev/null; then
        log_warning "VM already exists. Skipping creation."
        return 0
    fi
    
    log_info "Deploying Ubuntu VM (no cloud-init, avoids timeout issues)..."
    
    az vm create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$VM_NAME" \
        --location "$LOCATION" \
        --nics "$NIC_NAME" \
        --size "$VM_SIZE" \
        --image "$VM_IMAGE" \
        --admin-username "$ADMIN_USERNAME" \
        --ssh-key-values "@${SSH_KEY_PATH}.pub" \
        --public-ip-address "" \
        --output none
    
    log_success "Virtual Machine created: $VM_NAME"
}

# Function to wait for VM to be accessible
wait_for_vm() {
    log_step "Waiting for VM to be accessible via SSH..."
    
    local max_attempts=20
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if ssh -i "$SSH_KEY_PATH" \
               -o StrictHostKeyChecking=no \
               -o ConnectTimeout=5 \
               -o BatchMode=yes \
               "$ADMIN_USERNAME@$PUBLIC_IP" \
               "echo 'connected'" &>/dev/null; then
            log_success "VM is accessible via SSH!"
            return 0
        fi
        
        attempt=$((attempt + 1))
        echo -n "."
        sleep 5
    done
    
    log_warning "Timeout waiting for SSH. VM may still be initializing."
    return 1
}

# Function to install and configure NGINX via SSH
install_nginx() {
    log_step "Installing and configuring NGINX on VM..."
    
    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$ADMIN_USERNAME@$PUBLIC_IP" << 'ENDSSH'
        set -e
        
        echo "📦 Updating package lists..."
        sudo apt-get update -qq
        
        echo "📥 Installing NGINX..."
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nginx curl
        
        echo "🔧 Configuring firewall..."
        sudo ufw allow 'Nginx Full' || true
        sudo ufw allow OpenSSH || true
        echo "y" | sudo ufw enable || true
        
        echo "📝 Creating default website..."
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
            animation: fadeIn 1s ease;
        }
        @keyframes fadeIn {
            from { opacity: 0; transform: translateY(20px); }
            to { opacity: 1; transform: translateY(0); }
        }
        h1 {
            color: #667eea;
            font-size: 3em;
            margin-bottom: 20px;
        }
        .icon { 
            font-size: 5em; 
            margin-bottom: 20px;
            animation: bounce 2s infinite;
        }
        @keyframes bounce {
            0%, 100% { transform: translateY(0); }
            50% { transform: translateY(-10px); }
        }
        p {
            color: #666;
            font-size: 1.2em;
            line-height: 1.8;
            margin: 15px 0;
        }
        .status {
            background: #28a745;
            color: white;
            padding: 10px 25px;
            border-radius: 25px;
            display: inline-block;
            margin: 20px 0;
            font-weight: bold;
        }
        .info-box {
            background: #f8f9fa;
            border-left: 4px solid #667eea;
            padding: 20px;
            margin: 30px 0;
            text-align: left;
        }
        .info-box h3 {
            color: #667eea;
            margin-bottom: 15px;
        }
        .info-box ul {
            list-style: none;
            padding: 0;
        }
        .info-box li {
            padding: 8px 0;
            color: #555;
        }
        .info-box li:before {
            content: "✓ ";
            color: #28a745;
            font-weight: bold;
            margin-right: 8px;
        }
        code {
            background: #f4f4f4;
            padding: 3px 8px;
            border-radius: 4px;
            color: #667eea;
            font-family: 'Courier New', monospace;
        }
        .footer {
            margin-top: 40px;
            padding-top: 20px;
            border-top: 2px solid #e9ecef;
            color: #999;
            font-size: 0.9em;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="icon">🚀</div>
        <h1>Deployment Successful!</h1>
        <div class="status">● System Online</div>
        <p>Your Azure-powered static website is now live and serving content through NGINX on Ubuntu 22.04 LTS.</p>
        
        <div class="info-box">
            <h3>📊 Deployment Details</h3>
            <ul>
                <li>Cloud Provider: Microsoft Azure</li>
                <li>Web Server: NGINX (High Performance)</li>
                <li>Operating System: Ubuntu 22.04 LTS</li>
                <li>Deployment Method: Azure CLI (v2.0)</li>
                <li>Network Security: NSG with HTTP/HTTPS/SSH rules</li>
            </ul>
        </div>
        
        <div class="info-box">
            <h3>🔧 Next Steps</h3>
            <ul>
                <li>Replace this page with your custom HTML</li>
                <li>Upload files to <code>/var/www/html/</code></li>
                <li>Configure SSL certificate (Let's Encrypt)</li>
                <li>Set up custom domain name</li>
            </ul>
        </div>
        
        <p style="margin-top: 30px; font-size: 0.95em;">
            <strong>Pro Tip:</strong> Use <code>./scripts/deploy-website.sh</code> to update your site!
        </p>
        
        <div class="footer">
            Deployed with ❤️ using Azure Infrastructure as Code
        </div>
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
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript 
               application/x-javascript application/xml+rss application/json;
    
    # Cache static files
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
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
    
    log_success "NGINX installed and configured successfully!"
}

# Function to test website
test_website() {
    log_step "Testing website accessibility..."
    
    sleep 5
    
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$PUBLIC_IP" 2>/dev/null || echo "000")
    
    if [ "$HTTP_CODE" = "200" ]; then
        log_success "Website is accessible! HTTP Status: $HTTP_CODE"
    else
        log_warning "Website returned HTTP Status: $HTTP_CODE (may need more time)"
    fi
}

# Function to display summary
display_summary() {
    cat << EOF

╔═══════════════════════════════════════════════════════════════╗
║                    DEPLOYMENT SUCCESSFUL!                     ║
╚═══════════════════════════════════════════════════════════════╝

📊 Resource Summary:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Resource Group:    $RESOURCE_GROUP
  Location:          $LOCATION
  Virtual Machine:   $VM_NAME ($VM_SIZE)
  Public IP:         $PUBLIC_IP
  Admin User:        $ADMIN_USERNAME

🌐 Access Your Website:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Website URL:       http://$PUBLIC_IP
  SSH Access:        ssh -i $SSH_KEY_PATH $ADMIN_USERNAME@$PUBLIC_IP

📝 Next Steps:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  1. Visit http://$PUBLIC_IP in your browser
  2. Upload your custom website files to /var/www/html/
  3. Configure SSL certificate (optional but recommended)
  4. Set up custom domain name (optional)

💡 Useful Commands:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  View resources:    az resource list -g $RESOURCE_GROUP -o table
  Stop VM:           az vm stop -g $RESOURCE_GROUP -n $VM_NAME
  Start VM:          az vm start -g $RESOURCE_GROUP -n $VM_NAME
  Deploy website:    ./scripts/deploy-website.sh
  Delete all:        ./scripts/cleanup.sh

💰 Cost Estimate: ~\$12-15/month (Standard_B1s VM + Public IP)

⚠️  Remember to delete resources when done to avoid charges!

EOF
}

# Main execution flow
main() {
    local start_time=$(date +%s)
    
    echo ""
    log_info "Phase 1: Pre-deployment checks"
    check_azure_cli
    check_azure_login
    generate_ssh_key
    
    echo ""
    log_info "Phase 2: Creating Azure infrastructure"
    create_resource_group
    create_virtual_network
    create_nsg
    create_public_ip
    create_network_interface
    
    echo ""
    log_info "Phase 3: Deploying Virtual Machine"
    create_virtual_machine
    
    echo ""
    log_info "Phase 4: Configuring web server"
    wait_for_vm
    install_nginx
    
    echo ""
    log_info "Phase 5: Testing deployment"
    test_website
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo ""
    display_summary
    
    log_success "Deployment completed successfully in ${duration} seconds! 🎉"
}

# Error handling
trap 'log_error "An error occurred during deployment. Check the output above for details."' ERR

# Run main function
main "$@"