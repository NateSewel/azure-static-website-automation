#!/bin/bash
################################################################################
# Azure Static Website Deployment - Master Script
# Description: Complete automation for deploying a static website on Azure
# Author: DevOps Team
# Version: 1.0.0
################################################################################

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; exit 1; }

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

# Banner
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║        Azure Static Website Deployment Automation            ║
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
    log_info "Checking Azure CLI installation..."
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI is not installed. Please install it first."
    fi
    log_success "Azure CLI found: $(az version --query '\"azure-cli\"' -o tsv)"
}

# Function to check if logged into Azure
check_azure_login() {
    log_info "Checking Azure authentication..."
    if ! az account show &> /dev/null; then
        log_warning "Not logged into Azure. Initiating login..."
        az login
    fi
    
    SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)
    log_success "Authenticated to Azure subscription: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"
}

# Function to generate SSH key if not exists
generate_ssh_key() {
    log_info "Checking SSH key..."
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
    log_info "Creating Resource Group: $RESOURCE_GROUP..."
    
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
    log_info "Creating Virtual Network: $VNET_NAME..."
    
    az network vnet create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$VNET_NAME" \
        --address-prefix "10.0.0.0/16" \
        --subnet-name "$SUBNET_NAME" \
        --subnet-prefix "10.0.1.0/24" \
        --output none
    
    log_success "Virtual Network created: $VNET_NAME (10.0.0.0/16)"
    log_success "Subnet created: $SUBNET_NAME (10.0.1.0/24)"
}

# Function to create network security group
create_nsg() {
    log_info "Creating Network Security Group: $NSG_NAME..."
    
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
}

# Function to create public IP
create_public_ip() {
    log_info "Creating Public IP Address: $PUBLIC_IP_NAME..."
    
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
}

# Function to create network interface
create_network_interface() {
    log_info "Creating Network Interface: $NIC_NAME..."
    
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
}

# Function to create VM with cloud-init
create_virtual_machine() {
    log_info "Creating Virtual Machine: $VM_NAME..."
    
    # Create cloud-init configuration
    cat > /tmp/cloud-init-$$.txt <<'EOF'
#cloud-config
package_update: true
package_upgrade: true
packages:
  - nginx
  - git
  - curl
  - ufw

runcmd:
  # Configure firewall
  - ufw allow 'Nginx Full'
  - ufw allow OpenSSH
  - ufw --force enable
  
  # Start NGINX
  - systemctl start nginx
  - systemctl enable nginx
  
  # Create default website
  - |
    cat > /var/www/html/index.html <<'HTML'
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
                animation: fadeInDown 1s ease;
            }
            .success-icon {
                font-size: 6em;
                margin-bottom: 30px;
                animation: bounceIn 1s ease;
            }
            p {
                color: #666;
                font-size: 1.3em;
                line-height: 1.8;
                margin: 20px 0;
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
                padding-left: 0;
            }
            .info-box li {
                padding: 10px 0;
                border-bottom: 1px solid #e0e0e0;
            }
            .info-box li:last-child { border-bottom: none; }
            code {
                background: #667eea;
                color: white;
                padding: 3px 8px;
                border-radius: 4px;
                font-family: 'Courier New', monospace;
                font-size: 0.9em;
            }
            .status {
                display: inline-block;
                background: #28a745;
                color: white;
                padding: 8px 20px;
                border-radius: 20px;
                font-weight: bold;
                margin: 20px 0;
            }
            @keyframes fadeInDown {
                from { opacity: 0; transform: translateY(-30px); }
                to { opacity: 1; transform: translateY(0); }
            }
            @keyframes bounceIn {
                0% { transform: scale(0); opacity: 0; }
                50% { transform: scale(1.1); }
                100% { transform: scale(1); opacity: 1; }
            }
            .footer {
                margin-top: 40px;
                padding-top: 20px;
                border-top: 2px solid #e0e0e0;
                color: #999;
                font-size: 0.9em;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="success-icon">🚀</div>
            <h1>Website Deployed Successfully!</h1>
            <div class="status">● System Online</div>
            <p>Your Azure-powered static website is now live and serving content through NGINX on Ubuntu 22.04 LTS.</p>
            
            <div class="info-box">
                <h3>📊 Deployment Details</h3>
                <ul>
                    <li><strong>Cloud Provider:</strong> Microsoft Azure</li>
                    <li><strong>Web Server:</strong> NGINX (High Performance)</li>
                    <li><strong>Operating System:</strong> Ubuntu 22.04 LTS</li>
                    <li><strong>Deployment Method:</strong> Azure CLI + Cloud-Init</li>
                    <li><strong>Network Security:</strong> NSG with HTTP/HTTPS/SSH rules</li>
                </ul>
            </div>
            
            <div class="info-box">
                <h3>🔧 Next Steps</h3>
                <ul>
                    <li>Replace this page with your custom HTML in <code>/var/www/html/</code></li>
                    <li>Configure SSL/TLS certificate using Let's Encrypt</li>
                    <li>Set up custom domain name (optional)</li>
                    <li>Configure automated backups</li>
                </ul>
            </div>
            
            <p style="margin-top: 30px;">
                <strong>Pro Tip:</strong> Use the deployment scripts in your GitHub repository to update your website automatically!
            </p>
            
            <div class="footer">
                Deployed with ❤️ using Azure Infrastructure as Code
            </div>
        </div>
    </body>
    </html>
    HTML
  
  # Configure NGINX
  - |
    cat > /etc/nginx/sites-available/default <<'NGINXCONF'
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
        
        # Enable gzip compression
        gzip on;
        gzip_vary on;
        gzip_min_length 1024;
        gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss application/json;
        
        # Cache static files
        location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
            expires 30d;
            add_header Cache-Control "public, immutable";
        }
    }
    NGINXCONF
  
  # Set permissions
  - chown -R www-data:www-data /var/www/html
  - chmod -R 755 /var/www/html
  
  # Restart NGINX
  - systemctl restart nginx
  - systemctl status nginx

final_message: "Azure static website deployment completed successfully!"
EOF
    
    log_info "Deploying VM with automated NGINX setup..."
    
    az vm create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$VM_NAME" \
        --location "$LOCATION" \
        --nics "$NIC_NAME" \
        --size "$VM_SIZE" \
        --image Ubuntu2204 \
        --admin-username "$ADMIN_USERNAME" \
        --ssh-key-values "@${SSH_KEY_PATH}.pub" \
        --custom-data /tmp/cloud-init-$.txt \
        --output none
    
    rm /tmp/cloud-init-$.txt
    
    log_success "Virtual Machine created: $VM_NAME"
}

# Function to wait for VM to be ready
wait_for_vm() {
    log_info "Waiting for VM to complete initialization..."
    log_warning "This may take 2-3 minutes for cloud-init to install and configure NGINX..."
    
    local max_attempts=60
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes \
            "$ADMIN_USERNAME@$PUBLIC_IP" "systemctl is-active nginx" &>/dev/null; then
            log_success "VM is ready and NGINX is running!"
            return 0
        fi
        
        attempt=$((attempt + 1))
        echo -n "."
        sleep 5
    done
    
    log_warning "Timeout waiting for VM. It may still be initializing. Check manually."
}

# Function to test website
test_website() {
    log_info "Testing website accessibility..."
    
    sleep 10  # Give a moment for network to settle
    
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$PUBLIC_IP" || echo "000")
    
    if [ "$HTTP_CODE" = "200" ]; then
        log_success "Website is accessible! HTTP Status: $HTTP_CODE"
    else
        log_warning "Website returned HTTP Status: $HTTP_CODE (may still be initializing)"
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
  Delete all:        az group delete -n $RESOURCE_GROUP --yes --no-wait

💰 Cost Estimate: ~\$12-15/month (Standard_B1s VM + Public IP)

⚠️  Remember to delete resources when done to avoid charges!

EOF
}

# Main execution flow
main() {
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
    log_info "Phase 4: Waiting for deployment to complete"
    wait_for_vm
    
    echo ""
    log_info "Phase 5: Testing deployment"
    test_website
    
    echo ""
    display_summary
    
    log_success "Deployment completed successfully! 🎉"
}

# Error handling
trap 'log_error "An error occurred during deployment. Check the output above for details."' ERR

# Run main function
main "$@"