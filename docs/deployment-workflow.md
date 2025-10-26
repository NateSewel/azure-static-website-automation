Phase 1: Pre-deployment checks
├─ Check Azure CLI
├─ Check Azure login
└─ Generate SSH keys

Phase 2: Creating Azure infrastructure
├─ Resource Group
├─ Virtual Network
├─ Network Security Group
├─ Public IP Address
└─ Network Interface

Phase 3: Deploying Virtual Machine
└─ Create VM (without cloud-init)

Phase 4: Configuring web server
├─ Wait for SSH access
└─ Install & configure NGINX

Phase 5: Testing deployment
└─ Verify website accessibility
