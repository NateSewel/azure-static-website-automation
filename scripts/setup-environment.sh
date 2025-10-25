#!/bin/bash
# setup-environment.sh - Initialize project environment

set -euo pipefail

echo "🚀 Setting up Azure Static Website Deployment Environment..."

# Login to Azure
echo "📝 Logging into Azure..."
az login

# List and select subscription
echo "📋 Available subscriptions:"
az account list --output table

echo ""
read -p "Enter your Subscription ID: " SUBSCRIPTION_ID
az account set --subscription "$SUBSCRIPTION_ID"

echo "✅ Using subscription: $(az account show --query name -o tsv)"

# Generate SSH key if not exists
SSH_KEY_PATH="$HOME/.ssh/azure_website_key"
if [ ! -f "$SSH_KEY_PATH" ]; then
    echo "🔑 Generating SSH key..."
    ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N "" -C "azure-website-deployment"
    echo "✅ SSH key generated at $SSH_KEY_PATH"
else
    echo "✅ SSH key already exists at $SSH_KEY_PATH"
fi

echo ""
echo "✅ Environment setup complete!"
echo "🔑 SSH Public Key:"
cat "${SSH_KEY_PATH}.pub"