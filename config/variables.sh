#!/bin/bash
################################################################################
# Configuration Variables for Azure Static Website Deployment
# Description: Centralized configuration for all deployment scripts
# Usage: source config/variables.sh
################################################################################

# Resource Group Configuration
export RESOURCE_GROUP="${RESOURCE_GROUP:-static-website-rg}"
export LOCATION="${LOCATION:-eastus}"

# Virtual Network Configuration
export VNET_NAME="${VNET_NAME:-website-vnet}"
export VNET_PREFIX="${VNET_PREFIX:-10.0.0.0/16}"
export SUBNET_NAME="${SUBNET_NAME:-website-subnet}"
export SUBNET_PREFIX="${SUBNET_PREFIX:-10.0.1.0/24}"

# Network Security Group Configuration
export NSG_NAME="${NSG_NAME:-website-nsg}"

# Public IP Configuration
export PUBLIC_IP_NAME="${PUBLIC_IP_NAME:-website-public-ip}"
export DNS_NAME="${DNS_NAME:-mystaticwebsite$RANDOM}"  # Must be globally unique

# Network Interface Configuration
export NIC_NAME="${NIC_NAME:-website-nic}"

# Virtual Machine Configuration
export VM_NAME="${VM_NAME:-website-vm}"
export VM_SIZE="${VM_SIZE:-Standard_B1s}"  # Options: Standard_B1s, Standard_B1ms, Standard_B2s
export VM_IMAGE="${VM_IMAGE:-Ubuntu2204}"  # Ubuntu 22.04 LTS
export ADMIN_USERNAME="${ADMIN_USERNAME:-azureuser}"

# SSH Configuration
export SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/azure_website_key}"
export SSH_KEY_PUBLIC="${SSH_KEY_PUBLIC:-${SSH_KEY_PATH}.pub}"

# Tags for Resources
export TAG_ENVIRONMENT="${TAG_ENVIRONMENT:-Production}"
export TAG_PROJECT="${TAG_PROJECT:-StaticWebsite}"
export TAG_OWNER="${TAG_OWNER:-DevOps}"
export TAG_COST_CENTER="${TAG_COST_CENTER:-Engineering}"

# Web Server Configuration
export WEB_SERVER="${WEB_SERVER:-nginx}"  # Options: nginx, apache
export WEBSITE_DIR="${WEBSITE_DIR:-./website}"

# Optional: Custom Domain (if you have one)
export CUSTOM_DOMAIN="${CUSTOM_DOMAIN:-}"  # e.g., www.example.com

# Azure Subscription (will be auto-detected if not set)
export SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-}"

# Deployment Options
export AUTO_APPROVE="${AUTO_APPROVE:-false}"  # Set to 'true' to skip confirmations
export VERBOSE="${VERBOSE:-false}"            # Set to 'true' for verbose output
export DRY_RUN="${DRY_RUN:-false}"            # Set to 'true' to preview without creating

# Color codes for output (used by scripts)
export COLOR_RED='\033[0;31m'
export COLOR_GREEN='\033[0;32m'
export COLOR_YELLOW='\033[1;33m'
export COLOR_BLUE='\033[0;34m'
export COLOR_NC='\033[0m'  # No Color

# Validation
validate_config() {
    local errors=0
    
    echo "🔍 Validating configuration..."
    
    # Check required variables
    if [ -z "$RESOURCE_GROUP" ]; then
        echo "❌ RESOURCE_GROUP is not set"
        ((errors++))
    fi
    
    if [ -z "$LOCATION" ]; then
        echo "❌ LOCATION is not set"
        ((errors++))
    fi
    
    if [ -z "$ADMIN_USERNAME" ]; then
        echo "❌ ADMIN_USERNAME is not set"
        ((errors++))
    fi
    
    # Validate Azure location
    if ! az account list-locations --query "[?name=='$LOCATION']" -o tsv &>/dev/null; then
        echo "⚠️  Warning: Location '$LOCATION' might not be valid"
    fi
    
    # Validate VM size format
    if [[ ! "$VM_SIZE" =~ ^Standard_ ]]; then
        echo "⚠️  Warning: VM_SIZE should start with 'Standard_'"
    fi
    
    # Validate CIDR notation
    if [[ ! "$VNET_PREFIX" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
        echo "❌ VNET_PREFIX is not in valid CIDR notation"
        ((errors++))
    fi
    
    if [ $errors -gt 0 ]; then
        echo "❌ Configuration validation failed with $errors error(s)"
        return 1
    fi
    
    echo "✅ Configuration validation passed"
    return 0
}

# Display current configuration
show_config() {
    cat << EOF

╔═══════════════════════════════════════════════════════════════╗
║              Azure Deployment Configuration                   ║
╚═══════════════════════════════════════════════════════════════╝

📦 Resource Configuration:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Resource Group:      $RESOURCE_GROUP
  Location:            $LOCATION
  Environment:         $TAG_ENVIRONMENT
  Project:             $TAG_PROJECT

🌐 Network Configuration:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  VNet Name:           $VNET_NAME
  VNet CIDR:           $VNET_PREFIX
  Subnet Name:         $SUBNET_NAME
  Subnet CIDR:         $SUBNET_PREFIX
  NSG Name:            $NSG_NAME
  Public IP:           $PUBLIC_IP_NAME
  DNS Name:            $DNS_NAME

🖥️  Virtual Machine Configuration:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  VM Name:             $VM_NAME
  VM Size:             $VM_SIZE
  OS Image:            $VM_IMAGE
  Admin User:          $ADMIN_USERNAME
  SSH Key:             $SSH_KEY_PATH

🌍 Web Server Configuration:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Web Server:          $WEB_SERVER
  Website Directory:   $WEBSITE_DIR
  Custom Domain:       ${CUSTOM_DOMAIN:-Not configured}

⚙️  Deployment Options:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Auto Approve:        $AUTO_APPROVE
  Verbose Output:      $VERBOSE
  Dry Run:             $DRY_RUN

EOF
}

# Export all functions
export -f validate_config
export -f show_config

# If sourced with --validate, run validation
if [ "${1:-}" = "--validate" ]; then
    validate_config
fi

# If sourced with --show, display configuration
if [ "${1:-}" = "--show" ]; then
    show_config
fi

# Success message
echo "✅ Configuration variables loaded successfully"
echo "   Run 'source config/variables.sh --show' to display all values"
echo "   Run 'source config/variables.sh --validate' to validate configuration"