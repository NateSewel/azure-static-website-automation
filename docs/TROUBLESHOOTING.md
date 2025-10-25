# Troubleshooting Guide 🔧

Comprehensive solutions for common issues when deploying Azure static websites.

## Table of Contents

- [Deployment Issues](#deployment-issues)
- [Network and Connectivity](#network-and-connectivity)
- [VM and SSH Issues](#vm-and-ssh-issues)
- [NGINX and Web Server](#nginx-and-web-server)
- [GitHub Actions](#github-actions)
- [Performance Issues](#performance-issues)
- [Diagnostic Commands](#diagnostic-commands)

---

## Deployment Issues

### ❌ Error: "Subscription not found"

**Symptoms:**

```
ERROR: Subscription 'xxx' not found
```

**Solution:**

```bash
# List available subscriptions
az account list --output table

# Set the correct subscription
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# Verify
az account show
```

---

### ❌ Error: "Location not available"

**Symptoms:**

```
ERROR: Location 'xxx' is not available for resource type 'Microsoft.Compute/virtualMachines'
```

**Solution:**

```bash
# List available locations
az account list-locations --output table

# Edit config/variables.sh
export LOCATION="eastus"  # or another available region

# Re-run deployment
./scripts/deploy.sh
```

---

### ❌ Error: "Quota exceeded"

**Symptoms:**

```
ERROR: Operation could not be completed as it results in exceeding approved quota
```

**Solution:**

```bash
# Check current quota usage
az vm list-usage --location eastus --output table

# Solutions:
# 1. Use a smaller VM size (B1s instead of B2s)
# 2. Delete unused resources
# 3. Request quota increase via Azure Portal
```

---

### ❌ Error: "Resource group already exists"

**Symptoms:**

```
ERROR: Resource group 'static-website-rg' already exists
```

**Solution:**

```bash
# Option 1: Use existing resource group
# Script will skip creation

# Option 2: Delete and recreate
./scripts/cleanup.sh
./scripts/deploy.sh

# Option 3: Change resource group name
export RESOURCE_GROUP="my-new-rg"
./scripts/deploy.sh
```

---

## Network and Connectivity

### ❌ Cannot Access Website (404 or Connection Refused)

**Diagnostic Steps:**

```bash
# 1. Verify VM is running
az vm get-instance-view \
  --resource-group static-website-rg \
  --name website-vm \
  --query instanceView.statuses

# 2. Check public IP
PUBLIC_IP=$(az network public-ip show \
  --resource-group static-website-rg \
  --name website-public-ip \
  --query ipAddress -o tsv)
echo $PUBLIC_IP

# 3. Test HTTP connectivity
curl -v http://$PUBLIC_IP

# 4. Check NSG rules
az network nsg rule list \
  --resource-group static-website-rg \
  --nsg-name website-nsg \
  --output table
```

**Common Fixes:**

```bash
# Fix 1: Ensure NSG allows port 80
az network nsg rule create \
  --resource-group static-website-rg \
  --nsg-name website-nsg \
  --name AllowHTTP \
  --priority 100 \
  --destination-port-ranges 80 \
  --access Allow \
  --protocol Tcp

# Fix 2: Check NGINX is running (SSH required)
ssh -i ~/.ssh/azure_website_key azureuser@$PUBLIC_IP \
  "sudo systemctl status nginx"

# Fix 3: Restart NGINX
ssh -i ~/.ssh/azure_website_key azureuser@$PUBLIC_IP \
  "sudo systemctl restart nginx"
```

---

### ❌ Error: "502 Bad Gateway"

**Symptoms:**

- Browser shows "502 Bad Gateway"
- NGINX is running but can't serve content

**Solution:**

```bash
# SSH to VM
ssh -i ~/.ssh/azure_website_key azureuser@YOUR_PUBLIC_IP

# Check NGINX error logs
sudo tail -50 /var/log/nginx/error.log

# Check if files exist
ls -la /var/www/html/

# Fix permissions
sudo chown -R www-data:www-data /var/www/html
sudo chmod -R 755 /var/www/html

# Test NGINX configuration
sudo nginx -t

# Restart NGINX
sudo systemctl restart nginx

# Check status
sudo systemctl status nginx
```

---

### ❌ Error: "Connection Timeout"

**Symptoms:**

- `curl` or browser times out
- Cannot reach website or SSH

**Diagnostic:**

```bash
# Check VM is running
az vm get-instance-view \
  --resource-group static-website-rg \
  --name website-vm \
  --query "instanceView.statuses[?starts_with(code, 'PowerState/')].displayStatus" \
  --output tsv

# Check NSG rules are applied
az network nic show-effective-nsg \
  --resource-group static-website-rg \
  --name website-nic

# Verify public IP is assigned
az network nic ip-config show \
  --resource-group static-website-rg \
  --nic-name website-nic \
  --name ipconfig1 \
  --query publicIpAddress.id
```

**Solution:**

```bash
# Start VM if stopped
az vm start --resource-group static-website-rg --name website-vm

# Verify NSG is attached to NIC
az network nic update \
  --resource-group static-website-rg \
  --name website-nic \
  --network-security-group website-nsg
```

---

## VM and SSH Issues

### ❌ Error: "Permission denied (publickey)"

**Symptoms:**

```
Permission denied (publickey).
```

**Solution:**

```bash
# 1. Verify SSH key exists
ls -la ~/.ssh/azure_website_key*

# 2. Check key permissions
chmod 600 ~/.ssh/azure_website_key
chmod 644 ~/.ssh/azure_website_key.pub

# 3. Verify public key is deployed to VM
az vm show \
  --resource-group static-website-rg \
  --name website-vm \
  --query "osProfile.linuxConfiguration.ssh.publicKeys"

# 4. If key is missing, reset VM SSH
az vm user update \
  --resource-group static-website-rg \
  --name website-vm \
  --username azureuser \
  --ssh-key-value "$(cat ~/.ssh/azure_website_key.pub)"

# 5. Try SSH with verbose output
ssh -v -i ~/.ssh/azure_website_key azureuser@YOUR_PUBLIC_IP
```

---

### ❌ Cloud-Init Not Completing

**Symptoms:**

- NGINX not installed after 10+ minutes
- Website not accessible
- SSH works but web server missing

**Diagnostic:**

```bash
# Check cloud-init status
ssh -i ~/.ssh/azure_website_key azureuser@YOUR_PUBLIC_IP \
  "cloud-init status --long"

# View cloud-init logs
ssh -i ~/.ssh/azure_website_key azureuser@YOUR_PUBLIC_IP \
  "sudo cat /var/log/cloud-init-output.log"

# Check for errors
ssh -i ~/.ssh/azure_website_key azureuser@YOUR_PUBLIC_IP \
  "sudo journalctl -u cloud-init -n 100"
```

**Solution:**

```bash
# Option 1: Wait longer (can take up to 5 minutes)

# Option 2: Manually install NGINX
ssh -i ~/.ssh/azure_website_key azureuser@YOUR_PUBLIC_IP << 'EOF'
  sudo apt-get update
  sudo apt-get install -y nginx
  sudo systemctl start nginx
  sudo systemctl enable nginx
EOF

# Option 3: Redeploy VM
az vm delete --resource-group static-website-rg --name website-vm --yes
./scripts/create-vm.sh
```

---

### ❌ VM Won't Start

**Symptoms:**

- VM stuck in "Starting" state
- Deployment fails during VM creation

**Diagnostic:**

```bash
# Check VM provisioning state
az vm get-instance-view \
  --resource-group static-website-rg \
  --name website-vm \
  --query "instanceView.statuses"

# View activity log
az monitor activity-log list \
  --resource-group static-website-rg \
  --max-events 10

# Check boot diagnostics
az vm boot-diagnostics get-boot-log \
  --resource-group static-website-rg \
  --name website-vm
```

**Solution:**

```bash
# Deallocate and restart
az vm deallocate --resource-group static-website-rg --name website-vm
az vm start --resource-group static-website-rg --name website-vm

# If still failing, delete and recreate
az vm delete --resource-group static-website-rg --name website-vm --yes
./scripts/create-vm.sh
```

---

## NGINX and Web Server

### ❌ NGINX Fails to Start

**Diagnostic:**

```bash
ssh -i ~/.ssh/azure_website_key azureuser@YOUR_PUBLIC_IP << 'EOF'
  # Check NGINX status
  sudo systemctl status nginx

  # Test configuration
  sudo nginx -t

  # View error logs
  sudo tail -50 /var/log/nginx/error.log

  # Check if port 80 is in use
  sudo netstat -tulpn | grep :80
EOF
```

**Common Fixes:**

```bash
ssh -i ~/.ssh/azure_website_key azureuser@YOUR_PUBLIC_IP << 'EOF'
  # Fix 1: Port conflict - stop conflicting service
  sudo systemctl stop apache2  # if Apache is installed

  # Fix 2: Configuration syntax error
  sudo nginx -t  # Shows exact error
  # Edit config based on error
  sudo nano /etc/nginx/sites-available/default

  # Fix 3: Permissions issue
  sudo chown -R www-data:www-data /var/www/html
  sudo chmod -R 755 /var/www/html

  # Restart NGINX
  sudo systemctl restart nginx
EOF
```

---

### ❌ Website Shows Default NGINX Page

**Symptoms:**

- Browser shows "Welcome to nginx!" instead of your website

**Solution:**

```bash
# Check if your HTML files are present
ssh -i ~/.ssh/azure_website_key azureuser@YOUR_PUBLIC_IP \
  "ls -la /var/www/html/"

# If files are missing, deploy them
./scripts/deploy-website.sh

# Or manually copy
scp -i ~/.ssh/azure_website_key -r website/* \
  azureuser@YOUR_PUBLIC_IP:/tmp/

ssh -i ~/.ssh/azure_website_key azureuser@YOUR_PUBLIC_IP << 'EOF'
  sudo rm -rf /var/www/html/*
  sudo mv /tmp/* /var/www/html/
  sudo chown -R www-data:www-data /var/www/html
  sudo systemctl restart nginx
EOF
```

---

### ❌ Static Files Not Loading (CSS/JS/Images)

**Symptoms:**

- HTML loads but CSS/JavaScript/images show 404
- Browser console shows errors

**Diagnostic:**

```bash
ssh -i ~/.ssh/azure_website_key azureuser@YOUR_PUBLIC_IP << 'EOF'
  # Check file structure
  tree /var/www/html/  # or: find /var/www/html/

  # Check file permissions
  ls -laR /var/www/html/

  # Check NGINX access logs
  sudo tail -50 /var/log/nginx/access.log
EOF
```

**Solution:**

```bash
ssh -i ~/.ssh/azure_website_key azureuser@YOUR_PUBLIC_IP << 'EOF'
  # Fix 1: Correct permissions
  sudo find /var/www/html -type d -exec chmod 755 {} \;
  sudo find /var/www/html -type f -exec chmod 644 {} \;
  sudo chown -R www-data:www-data /var/www/html

  # Fix 2: Verify NGINX mime types
  sudo nginx -T | grep mime.types

  # Fix 3: Check for case sensitivity issues
  # Linux is case-sensitive! style.css ≠ Style.css

  sudo systemctl restart nginx
EOF
```

---

## GitHub Actions

### ❌ GitHub Actions: Authentication Failed

**Symptoms:**

```
ERROR: AADSTS700016: Application with identifier 'xxx' was not found
```

**Solution:**

```bash
# 1. Create new service principal
az ad sp create-for-rbac \
  --name "github-actions-sp-$(date +%s)" \
  --role contributor \
  --scopes /subscriptions/YOUR_SUB_ID/resourceGroups/static-website-rg \
  --sdk-auth

# 2. Copy the JSON output

# 3. Update GitHub Secret
# Go to: GitHub Repository → Settings → Secrets → AZURE_CREDENTIALS
# Update with new JSON
```

---

### ❌ GitHub Actions: SSH Connection Failed

**Symptoms:**

```
Permission denied (publickey)
```

**Solution:**

```bash
# 1. Verify SSH private key format in GitHub Secrets
# Must be the PRIVATE key (not public)
cat ~/.ssh/azure_website_key

# 2. Copy the ENTIRE key including:
# -----BEGIN OPENSSH PRIVATE KEY-----
# [key content]
# -----END OPENSSH PRIVATE KEY-----

# 3. Update GitHub Secret: SSH_PRIVATE_KEY
# Paste the complete private key

# 4. Ensure no extra spaces or newlines
```

---

### ❌ GitHub Actions: Cannot Find Public IP

**Symptoms:**

```
ERROR: Resource 'website-public-ip' not found
```

**Solution:**

```bash
# Verify resource names match
az network public-ip list \
  --resource-group static-website-rg \
  --output table

# Update workflow if names differ
# Edit .github/workflows/deploy.yml
```

---

## Performance Issues

### ❌ Website Loads Slowly

**Diagnostic:**

```bash
# Test response time
curl -w "\nTime: %{time_total}s\n" -o /dev/null -s http://YOUR_PUBLIC_IP

# Check VM metrics
az monitor metrics list \
  --resource $(az vm show -g static-website-rg -n website-vm --query id -o tsv) \
  --metric "Percentage CPU" \
  --output table
```

**Solutions:**

```bash
# 1. Enable and verify gzip compression
ssh -i ~/.ssh/azure_website_key azureuser@YOUR_PUBLIC_IP << 'EOF'
  # Check if gzip is enabled
  sudo nginx -T | grep gzip

  # Test gzip
  curl -H "Accept-Encoding: gzip" -I http://localhost
EOF

# 2. Verify caching headers
curl -I http://YOUR_PUBLIC_IP

# Should see:
# Cache-Control: public, max-age=xxx

# 3. Optimize images (before uploading)
# Use tools like ImageOptim, TinyPNG

# 4. Consider upgrading VM size
az vm resize \
  --resource-group static-website-rg \
  --name website-vm \
  --size Standard_B2s
```

---

### ❌ High Memory Usage

**Diagnostic:**

```bash
ssh -i ~/.ssh/azure_website_key azureuser@YOUR_PUBLIC_IP << 'EOF'
  # Check memory usage
  free -h

  # Check NGINX worker processes
  ps aux | grep nginx

  # Check for memory leaks
  top -o %MEM
EOF
```

**Solution:**

```bash
ssh -i ~/.ssh/azure_website_key azureuser@YOUR_PUBLIC_IP << 'EOF'
  # Optimize NGINX worker processes
  sudo nano /etc/nginx/nginx.conf
  # Set: worker_processes auto;
  # Set: worker_connections 1024;

  # Restart NGINX
  sudo systemctl restart nginx

  # Or upgrade VM to B1ms (2GB RAM)
EOF
```

---

## Diagnostic Commands

### Complete Health Check Script

```bash
#!/bin/bash
# health-check.sh - Complete diagnostic script

RESOURCE_GROUP="static-website-rg"
VM_NAME="website-vm"
PUBLIC_IP_NAME="website-public-ip"

echo "🔍 Azure Static Website Health Check"
echo "====================================="
echo ""

# 1. Check Azure authentication
echo "1️⃣ Azure Authentication:"
if az account show &>/dev/null; then
    echo "✅ Logged in as: $(az account show --query user.name -o tsv)"
else
    echo "❌ Not logged in to Azure"
    exit 1
fi
echo ""

# 2. Check resource group
echo "2️⃣ Resource Group:"
if az group show --name $RESOURCE_GROUP &>/dev/null; then
    echo "✅ Resource group exists"
else
    echo "❌ Resource group not found"
    exit 1
fi
echo ""

# 3. Check VM status
echo "3️⃣ Virtual Machine:"
VM_STATUS=$(az vm get-instance-view \
    --resource-group $RESOURCE_GROUP \
    --name $VM_NAME \
    --query "instanceView.statuses[?starts_with(code, 'PowerState/')].displayStatus" \
    --output tsv 2>/dev/null)

if [ "$VM_STATUS" = "VM running" ]; then
    echo "✅ VM is running"
else
    echo "⚠️  VM status: ${VM_STATUS:-Not found}"
fi
echo ""

# 4. Check public IP
echo "4️⃣ Public IP Address:"
PUBLIC_IP=$(az network public-ip show \
    --resource-group $RESOURCE_GROUP \
    --name $PUBLIC_IP_NAME \
    --query ipAddress \
    --output tsv 2>/dev/null)

if [ -n "$PUBLIC_IP" ]; then
    echo "✅ Public IP: $PUBLIC_IP"
else
    echo "❌ Public IP not found"
    exit 1
fi
echo ""

# 5. Check NSG rules
echo "5️⃣ Network Security Rules:"
HTTP_RULE=$(az network nsg rule list \
    --resource-group $RESOURCE_GROUP \
    --nsg-name website-nsg \
    --query "[?destinationPortRange=='80'].name" \
    --output tsv 2>/dev/null)

if [ -n "$HTTP_RULE" ]; then
    echo "✅ HTTP rule configured"
else
    echo "⚠️  HTTP rule not found"
fi
echo ""

# 6. Test HTTP connectivity
echo "6️⃣ HTTP Connectivity:"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$PUBLIC_IP" 2>/dev/null)

if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Website accessible (HTTP $HTTP_CODE)"
else
    echo "⚠️  Website returned HTTP $HTTP_CODE"
fi
echo ""

# 7. Test response time
echo "7️⃣ Performance:"
RESPONSE_TIME=$(curl -o /dev/null -s -w '%{time_total}' "http://$PUBLIC_IP" 2>/dev/null)
echo "⏱️  Response time: ${RESPONSE_TIME}s"
echo ""

# 8. SSH connectivity
echo "8️⃣ SSH Connectivity:"
if [ -f ~/.ssh/azure_website_key ]; then
    if ssh -i ~/.ssh/azure_website_key -o ConnectTimeout=5 -o BatchMode=yes \
        azureuser@$PUBLIC_IP "echo 'SSH OK'" &>/dev/null; then
        echo "✅ SSH connection successful"
    else
        echo "⚠️  Cannot connect via SSH"
    fi
else
    echo "⚠️  SSH key not found at ~/.ssh/azure_website_key"
fi
echo ""

# Summary
echo "📊 Summary:"
echo "==========="
echo "🌐 Website URL: http://$PUBLIC_IP"
echo "🔑 SSH Command: ssh -i ~/.ssh/azure_website_key azureuser@$PUBLIC_IP"
echo ""

if [ "$HTTP_CODE" = "200" ] && [ "$VM_STATUS" = "VM running" ]; then
    echo "✅ All systems operational!"
else
    echo "⚠️  Some issues detected. Review the output above."
fi
```

Save this as `scripts/health-check.sh` and run:

```bash
chmod +x scripts/health-check.sh
./scripts/health-check.sh
```

---

### Useful One-Liners

```bash
# Quick status check
az vm show -g static-website-rg -n website-vm -d --query "[powerState,publicIps]" -o table

# Get all resource IDs
az resource list -g static-website-rg --query "[].{Name:name, Type:type, ID:id}" -o table

# Check costs
az consumption usage list --start-date $(date -d '30 days ago' +%Y-%m-%d) --end-date $(date +%Y-%m-%d) -o table

# View activity log
az monitor activity-log list -g static-website-rg --offset 1d --query "[].{Time:eventTimestamp, Status:status.value, Operation:operationName.localizedValue}" -o table

# Export NGINX config
ssh -i ~/.ssh/azure_website_key azureuser@$PUBLIC_IP "sudo cat /etc/nginx/sites-available/default" > nginx-backup.conf

# Backup website files
ssh -i ~/.ssh/azure_website_key azureuser@$PUBLIC_IP "sudo tar -czf /tmp/website-backup.tar.gz /var/www/html"
scp -i ~/.ssh/azure_website_key azureuser@$PUBLIC_IP:/tmp/website-backup.tar.gz ./

# View real-time NGINX logs
ssh -i ~/.ssh/azure_website_key azureuser@$PUBLIC_IP "sudo tail -f /var/log/nginx/access.log"

# Check disk usage
ssh -i ~/.ssh/azure_website_key azureuser@$PUBLIC_IP "df -h"

# Check running processes
ssh -i ~/.ssh/azure_website_key azureuser@$PUBLIC_IP "ps aux | grep nginx"

# Test SSL/TLS (if configured)
openssl s_client -connect $PUBLIC_IP:443 -servername yourdomain.com
```

---

## Emergency Recovery

### Complete System Restore

If everything is broken:

```bash
# 1. Backup your website files (if accessible)
./scripts/backup-website.sh

# 2. Complete cleanup
./scripts/cleanup.sh

# 3. Wait for deletion (check with)
az group show -n static-website-rg

# 4. Fresh deployment
./scripts/deploy.sh

# 5. Restore website files
./scripts/deploy-website.sh
```

---

## Getting Additional Help

### Collect Diagnostic Information

Before asking for help, collect this information:

```bash
# Create diagnostic report
cat > diagnostic-report.txt << EOF
=== Azure Static Website Diagnostic Report ===
Date: $(date)

1. Azure CLI Version:
$(az --version)

2. Subscription:
$(az account show)

3. Resource Group:
$(az group show -n static-website-rg 2>&1)

4. VM Status:
$(az vm show -g static-website-rg -n website-vm -d 2>&1)

5. Public IP:
$(az network public-ip show -g static-website-rg -n website-public-ip 2>&1)

6. NSG Rules:
$(az network nsg rule list -g static-website-rg --nsg-name website-nsg 2>&1)

7. HTTP Test:
$(curl -I http://$(az network public-ip show -g static-website-rg -n website-public-ip --query ipAddress -o tsv) 2>&1)

8. Recent Activity:
$(az monitor activity-log list -g static-website-rg --offset 2h 2>&1)
EOF

echo "Diagnostic report saved to: diagnostic-report.txt"
```

### Support Channels

1. **GitHub Issues**: Open an issue with your diagnostic report
2. **Azure Support**: https://azure.microsoft.com/support/
3. **Stack Overflow**: Tag with `azure`, `nginx`, `azure-cli`
4. **Azure Forums**: https://docs.microsoft.com/answers/

---

## Prevention Best Practices

### Before Deployment

- ✅ Test scripts in development subscription first
- ✅ Review cost estimates
- ✅ Set up budget alerts
- ✅ Document custom configurations

### During Operation

- ✅ Enable VM boot diagnostics
- ✅ Set up Azure Monitor alerts
- ✅ Regular backups of website files
- ✅ Monitor costs weekly

### Regular Maintenance

- ✅ Update Ubuntu packages monthly
- ✅ Review NGINX logs weekly
- ✅ Test disaster recovery procedures
- ✅ Audit security configurations

---

**📚 Additional Resources:**

- [Azure CLI Documentation](https://docs.microsoft.com/cli/azure/)
- [NGINX Documentation](https://nginx.org/en/docs/)
- [Azure VM Troubleshooting](https://docs.microsoft.com/azure/virtual-machines/troubleshooting/)
- [GitHub Actions Documentation](https://docs.github.com/actions)

---

Still having issues? Open a GitHub issue with your diagnostic report!
