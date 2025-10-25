# Quick Start Guide 🚀

Get your Azure static website up and running in under 10 minutes!

## Prerequisites Checklist ✅

Before you begin, make sure you have:

- [ ] Azure account with active subscription
- [ ] Azure CLI installed (`az --version` to check)
- [ ] Git installed
- [ ] Terminal/command line access
- [ ] 10-15 minutes of time

## Step-by-Step Setup

### 1️⃣ Clone the Repository

```bash
git clone https://github.com/yourusername/azure-static-website.git
cd azure-static-website
```

### 2️⃣ Make Scripts Executable

```bash
chmod +x scripts/*.sh
```

### 3️⃣ Login to Azure

```bash
az login
```

A browser window will open. Sign in with your Azure credentials.

### 4️⃣ Set Your Subscription

```bash
# List your subscriptions
az account list --output table

# Set the subscription you want to use
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

### 5️⃣ Deploy Everything!

```bash
# Run the master deployment script
./scripts/deploy.sh
```

This single command will:

- ✅ Generate SSH keys
- ✅ Create resource group
- ✅ Set up virtual network
- ✅ Configure security groups
- ✅ Deploy virtual machine
- ✅ Install and configure NGINX
- ✅ Deploy your website

**⏱️ Expected time: 5-7 minutes**

### 6️⃣ Access Your Website

After deployment completes, you'll see output like:

```
🌐 Website URL: http://20.123.45.67
🔑 SSH Access: ssh -i ~/.ssh/azure_website_key azureuser@20.123.45.67
```

Open the URL in your browser to see your live website! 🎉

## Customizing Your Website

### Option 1: Replace with Your Own Files

```bash
# Clear the example website
rm -rf website/*

# Copy your files
cp -r /path/to/your/website/* website/

# Deploy to Azure
./scripts/deploy-website.sh
```

### Option 2: Edit Directly on VM

```bash
# SSH into your VM
ssh -i ~/.ssh/azure_website_key azureuser@YOUR_PUBLIC_IP

# Edit files
sudo nano /var/www/html/index.html

# Changes are live immediately!
```

## Testing Your Deployment

```bash
# Test website accessibility
curl -I http://YOUR_PUBLIC_IP

# Expected output:
# HTTP/1.1 200 OK
# Server: nginx
```

## Common Commands

### View Your Resources

```bash
az resource list -g static-website-rg -o table
```

### Get Public IP Address

```bash
az network public-ip show \
  --resource-group static-website-rg \
  --name website-public-ip \
  --query ipAddress -o tsv
```

### SSH to Your VM

```bash
ssh -i ~/.ssh/azure_website_key azureuser@YOUR_PUBLIC_IP
```

### Stop VM (to save costs)

```bash
az vm deallocate -g static-website-rg -n website-vm
```

### Start VM

```bash
az vm start -g static-website-rg -n website-vm
```

### View NGINX Logs

```bash
ssh -i ~/.ssh/azure_website_key azureuser@YOUR_PUBLIC_IP \
  "sudo tail -f /var/log/nginx/access.log"
```

## Setting Up GitHub Actions (Optional)

### 1. Create Azure Service Principal

```bash
az ad sp create-for-rbac \
  --name "github-actions-sp" \
  --role contributor \
  --scopes /subscriptions/YOUR_SUB_ID/resourceGroups/static-website-rg \
  --sdk-auth
```

### 2. Add GitHub Secrets

Go to your repository → Settings → Secrets → New secret

**Add these two secrets:**

1. **AZURE_CREDENTIALS**: Paste the JSON output from step 1
2. **SSH_PRIVATE_KEY**: Content of `~/.ssh/azure_website_key`

```bash
# View your private key
cat ~/.ssh/azure_website_key
```

### 3. Push Changes

```bash
# Edit your website
echo "Hello from GitHub Actions!" > website/index.html

# Commit and push
git add website/
git commit -m "Update website"
git push origin main
```

GitHub Actions will automatically deploy your changes! 🚀

## Cleanup (When Done)

**⚠️ Warning: This deletes everything!**

```bash
./scripts/cleanup.sh
```

Type `DELETE` to confirm.

## Troubleshooting

### Issue: "Cannot connect to VM"

**Wait 2-3 minutes** after deployment. Cloud-init needs time to install NGINX.

Check status:

```bash
ssh -i ~/.ssh/azure_website_key azureuser@YOUR_PUBLIC_IP \
  "cloud-init status"
```

### Issue: "Website shows 502 Bad Gateway"

NGINX might not be running:

```bash
ssh -i ~/.ssh/azure_website_key azureuser@YOUR_PUBLIC_IP \
  "sudo systemctl restart nginx"
```

### Issue: "Permission denied (publickey)"

Check your SSH key path:

```bash
ls -la ~/.ssh/azure_website_key
```

If missing, the deployment script should have created it. Try running `./scripts/deploy.sh` again.

### Issue: "Resource already exists"

If deployment was interrupted:

```bash
# Delete and start fresh
./scripts/cleanup.sh
./scripts/deploy.sh
```

## Cost Information

**Estimated monthly cost: $12-16**

Breakdown:

- VM (B1s): ~$8-10/month
- Public IP: ~$3-4/month
- Storage: ~$1-2/month

**💡 Tip**: Delete resources when not needed to avoid charges!

## Next Steps

1. ✅ **Add Custom Domain**

   - Configure DNS to point to your public IP
   - Update NGINX server_name directive

2. ✅ **Enable HTTPS**

   - Install Certbot: `sudo apt install certbot python3-certbot-nginx`
   - Get certificate: `sudo certbot --nginx -d yourdomain.com`

3. ✅ **Set Up Monitoring**

   - Enable Azure Monitor
   - Configure alerts for VM health

4. ✅ **Implement Backups**

   - Schedule VM snapshots
   - Version control your website files

5. ✅ **Optimize Performance**
   - Configure CDN (Azure Front Door)
   - Implement caching strategies

## Getting Help

- 📖 Read the full [README.md](README.md)
- 🐛 Check [Troubleshooting Guide](docs/troubleshooting.md)
- 💬 Open an issue on GitHub
- 📧 Contact: your-email@example.com

## Success Checklist ✅

- [ ] Website accessible via HTTP
- [ ] Can SSH into VM
- [ ] NGINX running and serving content
- [ ] GitHub repository created
- [ ] Documentation reviewed
- [ ] Cost alerts configured (optional)
- [ ] Backup plan in place (optional)

---

**🎉 Congratulations! Your Azure static website is now live!**

Star ⭐ this project if you found it helpful!
