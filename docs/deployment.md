# MI-SOAR-NGFW Deployment Guide

## Overview

This document provides comprehensive deployment instructions for MI-SOAR-NGFW across different environments: local development (VirtualBox), Google Cloud Platform (Cloud Run and Compute Engine), and OVH cloud.

## Prerequisites

### Common Requirements
- Docker Engine 20.10+
- Docker Compose 2.0+
- Git
- 8GB RAM minimum (16GB recommended)
- 50GB free disk space

### Platform-Specific Requirements

#### Local/VirtualBox
- VirtualBox 6.1+
- Virtualization enabled in BIOS
- Network bridge configuration

#### Google Cloud Platform
- Google Cloud account with billing enabled
- gcloud CLI installed and authenticated
- Project with appropriate permissions

#### OVH Cloud
- OVH Cloud account
- Public cloud project
- Network configuration (vRack optional)

## Environment Setup

### 1. Clone Repository
```bash
git clone https://github.com/scryptocybershield/mi-soar-ngfw.git
cd mi-soar-ngfw
```

### 2. Configure Environment Variables
```bash
cp .env.example .env
# Edit .env with your configuration
```

### 3. Review Configuration Files
```bash
# Validate configurations
./scripts/monitoring/health-checks.sh --validate-only
```

## Local Deployment (VirtualBox)

### Step 1: VirtualBox Setup

1. Create a new virtual machine:
   - **Name**: mi-soar-ngfw
   - **Type**: Linux
   - **Version**: Debian (64-bit)
   - **Memory**: 8192 MB
   - **Hard Disk**: 50 GB VDI (dynamically allocated)

2. Configure network:
   - **Adapter 1**: Bridged Adapter
   - **Promiscuous Mode**: Allow All

3. Install Debian 11/12:
   - Minimal installation
   - SSH server enabled
   - Standard system utilities

### Step 2: Install Dependencies

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker Compose
sudo apt install -y docker-compose-plugin

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

### Step 3: Deploy Application

```bash
# Copy application files to VM
scp -r mi-soar-ngfw user@vm-ip:/home/user/

# SSH into VM
ssh user@vm-ip

# Start the platform
cd mi-soar-ngfw
docker-compose -f docker-compose.yml -f docker-compose.local.yml up -d
```

### Step 4: Verification

```bash
# Check container status
docker-compose ps

# Run health checks
./scripts/monitoring/health-checks.sh

# Access services
# Traefik Dashboard: http://vm-ip:8080
# n8n: http://vm-ip:5678
```

## GCP Cloud Run Deployment

### Step 1: Project Setup

```bash
# Set project
gcloud config set project YOUR_PROJECT_ID

# Enable required APIs
gcloud services enable \
  run.googleapis.com \
  containerregistry.googleapis.com \
  cloudbuild.googleapis.com \
  logging.googleapis.com \
  monitoring.googleapis.com \
  secretmanager.googleapis.com
```

### Step 2: Service Account Setup

```bash
# Create service account
gcloud iam service-accounts create mi-soar-ngfw-sa \
  --display-name="MI-SOAR-NGFW Service Account"

# Grant roles
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:mi-soar-ngfw-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/run.admin"

gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:mi-soar-ngfw-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/storage.admin"

# Create and download key
gcloud iam service-accounts keys create key.json \
  --iam-account=mi-soar-ngfw-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com
```

### Step 3: Automated Deployment (GitHub Actions)

1. Add secrets to GitHub repository:
   - `GCP_PROJECT_ID`: Your GCP project ID
   - `GCP_SA_KEY`: Contents of key.json (service account key)
   - `GCP_SA_EMAIL`: Service account email

2. Push to main branch or manually trigger workflow:
   - Go to **Actions** → **Deploy to GCP Cloud Run** → **Run workflow**

### Step 4: Manual Deployment

```bash
# Set environment variables
export PROJECT_ID=your-project-id
export REGION=europe-west1

# Run deployment script
./scripts/deploy/gcp-cloudrun.sh
```

### Step 5: Post-Deployment Configuration

```bash
# Get service URL
SERVICE_URL=$(gcloud run services describe mi-soar-ngfw \
  --region $REGION \
  --platform managed \
  --format 'value(status.url)')

# Configure custom domain (optional)
gcloud run domain-mappings create \
  --service mi-soar-ngfw \
  --domain your-domain.com \
  --region $REGION

# Set up monitoring alerts
gcloud alpha monitoring policies create \
  --policy-from-file=configs/monitoring/alert-policy.json
```

## GCP Compute Engine Deployment

### Step 1: Prepare Deployment Script

```bash
# Set environment variables
export PROJECT_ID=your-project-id
export ZONE=europe-west1-b
export MACHINE_TYPE=n2-standard-4

# Make scripts executable
chmod +x scripts/deploy/*.sh
```

### Step 2: Automated Deployment (GitHub Actions)

1. Ensure GitHub secrets are configured (same as Cloud Run)
2. Trigger GCE deployment workflow:
   - **Actions** → **Deploy to GCP Compute Engine** → **Run workflow**

### Step 3: Manual Deployment

```bash
# Run deployment script
./scripts/deploy/gcp-gce.sh
```

### Step 4: VM Configuration

The deployment script will:
1. Create a Compute Engine VM with optimized settings
2. Install Docker and dependencies
3. Copy application files
4. Configure systemd services
5. Set up firewall rules
6. Enable monitoring

### Step 5: Access and Management

```bash
# Get VM external IP
VM_IP=$(gcloud compute instances describe mi-soar-ngfw-vm \
  --zone $ZONE \
  --format 'value(networkInterfaces[0].accessConfigs[0].natIP)')

# SSH to VM
gcloud compute ssh mi-soar-ngfw-vm --zone $ZONE

# Check service status
sudo systemctl status mi-soar-ngfw

# View logs
sudo journalctl -u mi-soar-ngfw -f
```

## OVH Cloud Deployment

### Step 1: Create Instance

1. In OVH Control Panel:
   - Create a new public cloud project
   - Create an instance:
     - **Region**: Choose preferred region
     - **Model**: Discovery (for testing) or Production
     - **Image**: Debian 11 or Ubuntu 22.04
     - **Flavor**: b2-15 (4 vCPU, 15GB RAM) minimum

2. Configure network:
   - Create a public network
   - Configure security groups:
     - Allow SSH (22), HTTP (80), HTTPS (443)
     - Allow WireGuard (51820/udp)

### Step 2: Deploy Application

```bash
# SSH to OVH instance
ssh ubuntu@ovh-instance-ip

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Clone repository
git clone https://github.com/scryptocybershield/mi-soar-ngfw.git
cd mi-soar-ngfw

# Start with production configuration
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

### Step 3: Configure Networking

```bash
# Enable IP forwarding
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Configure iptables for Docker
sudo iptables -P FORWARD ACCEPT
```

## Multi-Environment Configuration

### Environment-Specific Overrides

| Environment | Compose Files | Configuration | Notes |
|-------------|---------------|---------------|-------|
| Development | `docker-compose.yml` + `docker-compose.local.yml` | Local volumes, debug logging | VirtualBox, local Docker |
| Staging | `docker-compose.yml` + `docker-compose.prod.yml` | Cloud storage, moderate resources | Cloud Run, test environment |
| Production | `docker-compose.yml` + `docker-compose.prod.yml` | High availability, monitoring | GCE, OVH, production |

### Configuration Management

1. **Environment Variables**: Use `.env` file for secrets
2. **Config Files**: Version-controlled in `configs/`
3. **Cloud Storage**: For Cloud Run deployments
4. **Secret Manager**: For production secrets (GCP Secret Manager, etc.)

## Health Verification

### Pre-Deployment Checks

```bash
# Validate configurations
suricata -T -c configs/suricata/suricata.yaml
nft --check -f configs/nftables/main.nft
docker-compose config

# Check script syntax
find scripts -name "*.sh" -exec bash -n {} \;
```

### Post-Deployment Verification

```bash
# Run comprehensive health checks
./scripts/monitoring/health-checks.sh

# Check individual services
curl -f http://localhost:5678/healthz  # n8n
curl -f http://localhost:55000  # Wazuh API
curl -f http://localhost:8080/api/rawdata  # Traefik

# Verify Suricata
docker exec mi-soar-suricata suricatasc -c uptime

# Verify WireGuard
docker exec mi-soar-wireguard wg show
```

### Monitoring Setup

```bash
# Enable Cloud Monitoring (GCP)
gcloud compute instances add-metadata INSTANCE_NAME \
  --metadata google-logging-enabled=true,google-monitoring-enabled=true

# Set up alert policies
./scripts/monitoring/setup-alerts.sh
```

## Scaling and Optimization

### Vertical Scaling

```bash
# Adjust container resources in docker-compose.prod.yml
services:
  suricata:
    deploy:
      resources:
        limits:
          cpus: '4'
          memory: 8G
```

### Horizontal Scaling (Cloud Run)

```bash
# Adjust Cloud Run configuration
gcloud run services update mi-soar-ngfw \
  --max-instances 10 \
  --concurrency 80 \
  --cpu 4 \
  --memory 8Gi
```

### Performance Tuning

1. **Suricata**:
   ```yaml
   environment:
     SURICATA_IFACE: eth0
     THREADS: auto
     AF_PACKET_MEMORY: 2048mb
   ```

2. **Wazuh**:
   ```yaml
   environment:
     WAZUH_CLUSTER_DISABLED: yes
     WAZUH_REGISTRATION_SERVER: 0.0.0.0
   ```

## Backup and Disaster Recovery

### Backup Procedures

```bash
# Backup configurations
tar -czf backup-configs-$(date +%Y%m%d).tar.gz configs/

# Backup Docker volumes
docker run --rm -v wazuh-data:/data -v $(pwd):/backup alpine \
  tar -czf /backup/wazuh-data-$(date +%Y%m%d).tar.gz /data

# Backup logs
tar -czf backup-logs-$(date +%Y%m%d).tar.gz storage/logs/
```

### Restoration Procedures

```bash
# Restore configurations
tar -xzf backup-configs-YYYYMMDD.tar.gz

# Restore Docker volumes
docker run --rm -v wazuh-data:/data -v $(pwd):/backup alpine \
  tar -xzf /backup/wazuh-data-YYYYMMDD.tar.gz -C /

# Restart services
docker-compose down
docker-compose up -d
```

### Disaster Recovery Testing

1. **Monthly**: Restore from backup in test environment
2. **Quarterly**: Full disaster recovery drill
3. **Annually**: Cross-region recovery test

## Security Hardening

### Container Security

```bash
# Apply security updates regularly
docker-compose pull
docker-compose up -d

# Scan for vulnerabilities
docker scan mi-soar-ngfw

# Use Docker content trust
export DOCKER_CONTENT_TRUST=1
```

### Network Security

```bash
# Configure firewall rules
./scripts/security/harden-network.sh

# Enable DDoS protection (cloud-specific)
# GCP: Cloud Armor
# OVH: Anti-DDoS
```

### Access Control

```bash
# Rotate credentials regularly
./scripts/security/rotate-credentials.sh

# Audit access logs
./scripts/security/audit-access.sh
```

## Troubleshooting

### Common Issues

#### Suricata Not Starting
```bash
# Check capabilities
docker exec mi-soar-suricata capsh --print

# Check interface
docker exec mi-soar-suricata ip link show

# View logs
docker-compose logs suricata
```

#### WireGuard Connection Issues
```bash
# Check WireGuard configuration
docker exec mi-soar-wireguard wg show

# Check firewall rules
docker exec mi-soar-nftables nft list ruleset

# Test connectivity
docker exec mi-soar-wireguard ping -c 4 8.8.8.8
```

#### n8n Workflow Errors
```bash
# Check n8n logs
docker-compose logs n8n

# Test webhook endpoints
curl -X POST http://localhost:5678/webhook/test

# Verify API connections
docker exec mi-soar-n8n curl -f http://wazuh:55000
```

### Log Locations

- **Docker Logs**: `docker-compose logs [service]`
- **Application Logs**: `storage/logs/[service]/`
- **System Logs**: `/var/log/syslog` (host)
- **Cloud Logging**: GCP Log Explorer or OVH Logs Data Platform

### Support Resources

1. **GitHub Issues**: Bug reports and feature requests
2. **Documentation**: `/docs` directory
3. **Community**: Security forums and Discord channels
4. **Professional Support**: Available for enterprise deployments

## Maintenance Schedule

### Daily
- Review health check reports
- Check for security alerts
- Monitor resource usage

### Weekly
- Update Suricata rules
- Review and prune logs
- Backup configurations

### Monthly
- Apply security updates
- Test backup restoration
- Review access logs

### Quarterly
- Update all container images
- Review and update firewall rules
- Disaster recovery testing

## Cost Optimization

### GCP Cloud Run
- Use minimum instances: 0 (scale to zero)
- Set maximum instances based on expected load
- Use Cloud Storage for infrequently accessed data
- Enable request-based scaling

### GCP Compute Engine
- Use committed use discounts
- Right-size VM instances
- Use preemptible VMs for non-critical workloads
- Implement auto-scaling based on metrics

### OVH Cloud
- Use flexible instances
- Leverage volume discounts
- Implement auto-scaling policies
- Use object storage for backups

## Compliance and Auditing

### Audit Trail
- Enable audit logging for all services
- Centralize logs in Wazuh SIEM
- Regular log review and analysis
- Retention according to compliance requirements

### Compliance Reports
- Generate monthly compliance reports
- Document security controls
- Maintain evidence for audits
- Regular vulnerability assessments

### Third-Party Audits
- Schedule annual security audits
- Penetration testing
- Code review by security experts
- Compliance certification updates