#!/bin/bash
# MI-SOAR-NGFW GCP Compute Engine Deployment Script
# Deploys the platform to Google Compute Engine VM

set -euo pipefail

# Configuration
PROJECT_ID="${PROJECT_ID:-}"
REGION="${REGION:-europe-west1}"
ZONE="${ZONE:-europe-west1-b}"
VM_NAME="mi-soar-ngfw-vm"
MACHINE_TYPE="n2-standard-4"
DISK_SIZE="100"
IMAGE_FAMILY="debian-11"
IMAGE_PROJECT="debian-cloud"
NETWORK="default"
SUBNET="default"
TAGS="mi-soar-ngfw,http-server,https-server"
SERVICE_ACCOUNT="${SERVICE_ACCOUNT:-default}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_dependencies() {
    if ! command -v gcloud &> /dev/null; then
        log_error "gcloud CLI is required but not installed"
        exit 1
    fi
}

validate_environment() {
    if [[ -z "$PROJECT_ID" ]]; then
        log_error "PROJECT_ID environment variable is required"
        exit 1
    fi

    gcloud config set project "$PROJECT_ID" > /dev/null 2>&1 || {
        log_error "Failed to set project to $PROJECT_ID"
        exit 1
    }
}

create_vm() {
    log_info "Creating Compute Engine VM instance..."

    # Check if VM already exists
    if gcloud compute instances describe "$VM_NAME" \
        --zone "$ZONE" \
        --project "$PROJECT_ID" > /dev/null 2>&1; then
        log_warn "VM $VM_NAME already exists, skipping creation"
        return 0
    fi

    # Create the VM
    gcloud compute instances create "$VM_NAME" \
        --zone "$ZONE" \
        --project "$PROJECT_ID" \
        --machine-type "$MACHINE_TYPE" \
        --image-family "$IMAGE_FAMILY" \
        --image-project "$IMAGE_PROJECT" \
        --boot-disk-size "${DISK_SIZE}GB" \
        --boot-disk-type "pd-ssd" \
        --network "$NETWORK" \
        --subnet "$SUBNET" \
        --tags "$TAGS" \
        --service-account "$SERVICE_ACCOUNT" \
        --scopes "cloud-platform" \
        --metadata-from-file startup-script=./scripts/deploy/gce-startup.sh \
        --metadata "project-id=$PROJECT_ID" \
        --min-cpu-platform "Intel Skylake" \
        --shielded-secure-boot \
        --shielded-vtpm \
        --shielded-integrity-monitoring || {
        log_error "Failed to create VM instance"
        exit 1
    }

    # Create firewall rules if needed
    create_firewall_rules

    log_info "VM instance created successfully"
}

create_firewall_rules() {
    log_info "Creating firewall rules..."

    # Allow HTTP
    if ! gcloud compute firewall-rules describe allow-http --project "$PROJECT_ID" > /dev/null 2>&1; then
        gcloud compute firewall-rules create allow-http \
            --project "$PROJECT_ID" \
            --allow tcp:80 \
            --source-ranges 0.0.0.0/0 \
            --target-tags http-server || {
            log_warn "Failed to create HTTP firewall rule"
        }
    fi

    # Allow HTTPS
    if ! gcloud compute firewall-rules describe allow-https --project "$PROJECT_ID" > /dev/null 2>&1; then
        gcloud compute firewall-rules create allow-https \
            --project "$PROJECT_ID" \
            --allow tcp:443 \
            --source-ranges 0.0.0.0/0 \
            --target-tags https-server || {
            log_warn "Failed to create HTTPS firewall rule"
        }
    fi

    # Allow WireGuard
    if ! gcloud compute firewall-rules describe allow-wireguard --project "$PROJECT_ID" > /dev/null 2>&1; then
        gcloud compute firewall-rules create allow-wireguard \
            --project "$PROJECT_ID" \
            --allow udp:51820 \
            --source-ranges 0.0.0.0/0 \
            --target-tags mi-soar-ngfw || {
            log_warn "Failed to create WireGuard firewall rule"
        }
    fi

    # Allow SSH from anywhere (restrict in production)
    if ! gcloud compute firewall-rules describe allow-ssh --project "$PROJECT_ID" > /dev/null 2>&1; then
        gcloud compute firewall-rules create allow-ssh \
            --project "$PROJECT_ID" \
            --allow tcp:22 \
            --source-ranges 0.0.0.0/0 \
            --target-tags mi-soar-ngfw || {
            log_warn "Failed to create SSH firewall rule"
        }
    fi
}

deploy_application() {
    log_info "Deploying application to VM..."

    # Get VM external IP
    local vm_ip=$(gcloud compute instances describe "$VM_NAME" \
        --zone "$ZONE" \
        --project "$PROJECT_ID" \
        --format 'value(networkInterfaces[0].accessConfigs[0].natIP)')

    if [[ -z "$vm_ip" ]]; then
        log_error "Failed to get VM IP address"
        exit 1
    fi

    log_info "VM IP address: $vm_ip"

    # Copy application files
    log_info "Copying application files to VM..."
    gcloud compute scp --recurse \
        --zone "$ZONE" \
        --project "$PROJECT_ID" \
        . "mi-soar-ngfw-user@$VM_NAME:/tmp/mi-soar-ngfw" || {
        log_error "Failed to copy files to VM"
        exit 1
    }

    # Execute deployment script on VM
    log_info "Running deployment script on VM..."
    gcloud compute ssh "mi-soar-ngfw-user@$VM_NAME" \
        --zone "$ZONE" \
        --project "$PROJECT_ID" \
        --command "cd /tmp/mi-soar-ngfw && sudo bash scripts/deploy/gce-deploy.sh" || {
        log_error "Failed to execute deployment script on VM"
        exit 1
    }

    log_info "Application deployed successfully to VM"
}

setup_monitoring() {
    log_info "Setting up monitoring and logging..."

    # Enable Cloud Monitoring and Logging
    gcloud compute instances add-metadata "$VM_NAME" \
        --zone "$ZONE" \
        --project "$PROJECT_ID" \
        --metadata google-logging-enabled=true,google-monitoring-enabled=true || {
        log_warn "Failed to enable monitoring on VM"
    }

    # Create alert policy for high CPU
    cat > /tmp/alert-policy.json << EOF
{
  "displayName": "MI-SOAR-NGFW High CPU",
  "conditions": [
    {
      "displayName": "VM Instance - CPU utilization",
      "conditionThreshold": {
        "filter": "resource.type=\"gce_instance\" AND resource.label.instance_id=\"$(gcloud compute instances describe $VM_NAME --zone $ZONE --project $PROJECT_ID --format 'value(id)')\"",
        "aggregations": [
          {
            "alignmentPeriod": "60s",
            "perSeriesAligner": "ALIGN_MEAN"
          }
        ],
        "comparison": "COMPARISON_GT",
        "thresholdValue": 0.8,
        "duration": "300s"
      }
    }
  ],
  "combiner": "OR"
}
EOF

    # Try to create alert policy
    if gcloud alpha monitoring policies create --policy-from-file=/tmp/alert-policy.json --project "$PROJECT_ID" > /dev/null 2>&1; then
        log_info "Alert policy created"
    else
        log_warn "Failed to create alert policy"
    fi
}

main() {
    log_info "Starting MI-SOAR-NGFW GCE deployment"

    check_dependencies
    validate_environment
    create_vm
    deploy_application
    setup_monitoring

    log_info "Deployment completed successfully!"
    log_info "VM Name: $VM_NAME"
    log_info "Zone: $ZONE"
    log_info "Next steps:"
    log_info "1. SSH to the VM: gcloud compute ssh $VM_NAME --zone $ZONE"
    log_info "2. Check application logs: sudo journalctl -u mi-soar-ngfw"
    log_info "3. Configure load balancer if needed"
    log_info "4. Set up automated backups"
}

# Run main function
main "$@"