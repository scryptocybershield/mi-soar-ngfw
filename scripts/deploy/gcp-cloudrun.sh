#!/bin/bash
# MI-SOAR-NGFW GCP Cloud Run Deployment Script
# Deploys the platform to Google Cloud Run with proper configuration

set -euo pipefail

# Configuration
PROJECT_ID="${PROJECT_ID:-}"
REGION="${REGION:-europe-west1}"
SERVICE_NAME="mi-soar-ngfw"
IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}:${BUILD_TAG:-latest}"
CONFIG_BUCKET="${CONFIG_BUCKET:-${PROJECT_ID}-mi-soar-configs}"

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
    local deps=("gcloud" "docker")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_error "$dep is required but not installed"
            exit 1
        fi
    done
}

validate_environment() {
    if [[ -z "$PROJECT_ID" ]]; then
        log_error "PROJECT_ID environment variable is required"
        exit 1
    fi

    # Set current project
    gcloud config set project "$PROJECT_ID" > /dev/null 2>&1 || {
        log_error "Failed to set project to $PROJECT_ID"
        exit 1
    }
}

build_and_push_image() {
    log_info "Building Docker image..."
    docker build -t "$IMAGE_NAME" . || {
        log_error "Docker build failed"
        exit 1
    }

    log_info "Pushing image to Google Container Registry..."
    docker push "$IMAGE_NAME" || {
        log_error "Failed to push image to GCR"
        exit 1
    }
}

upload_configs() {
    log_info "Uploading configurations to Cloud Storage..."

    # Create config bucket if it doesn't exist
    if ! gsutil ls -b "gs://$CONFIG_BUCKET" &> /dev/null; then
        gsutil mb -l "$REGION" "gs://$CONFIG_BUCKET" || {
            log_warn "Failed to create config bucket, using existing"
        }
    fi

    # Upload configs
    gsutil -m rsync -r ./configs "gs://${CONFIG_BUCKET}/configs" || {
        log_error "Failed to upload configurations"
        exit 1
    }

    # Create startup script that downloads configs
    cat > /tmp/startup-script.sh << 'EOF'
#!/bin/bash
# Startup script for Cloud Run instance
set -e

CONFIG_BUCKET="${CONFIG_BUCKET}"
CONFIG_DIR="/etc/mi-soar-ngfw"

if [[ -n "$CONFIG_BUCKET" ]]; then
    echo "Downloading configurations from gs://${CONFIG_BUCKET}..."
    gsutil -m rsync -r "gs://${CONFIG_BUCKET}/configs" "${CONFIG_DIR}"
fi

# Execute the main command
exec "$@"
EOF

    gsutil cp /tmp/startup-script.sh "gs://${CONFIG_BUCKET}/scripts/startup.sh" || {
        log_warn "Failed to upload startup script"
    }
}

deploy_to_cloudrun() {
    log_info "Deploying to Cloud Run..."

    # Prepare environment variables
    local env_vars=()
    env_vars+=("--set-env-vars=PROJECT_ID=${PROJECT_ID}")
    env_vars+=("--set-env-vars=CONFIG_BUCKET=${CONFIG_BUCKET}")
    env_vars+=("--set-env-vars=LOG_LEVEL=info")
    env_vars+=("--set-env-vars=SURICATA_IFACE=eth0")

    # Deploy the service
    gcloud run deploy "$SERVICE_NAME" \
        --image "$IMAGE_NAME" \
        --region "$REGION" \
        --platform managed \
        --allow-unauthenticated \
        --cpu 4 \
        --memory 8Gi \
        --max-instances 10 \
        --timeout 600 \
        --concurrency 80 \
        --port 8080 \
        --update-labels "managed-by=mi-soar-ngfw,environment=production" \
        --ingress all \
        "${env_vars[@]}" || {
        log_error "Cloud Run deployment failed"
        exit 1
    }

    # Get the service URL
    SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" \
        --region "$REGION" \
        --platform managed \
        --format 'value(status.url)')

    log_info "Service deployed successfully: ${SERVICE_URL}"
}

setup_iam() {
    log_info "Setting up IAM permissions..."

    # Grant Cloud Run service account access to config bucket
    local service_account=$(gcloud run services describe "$SERVICE_NAME" \
        --region "$REGION" \
        --platform managed \
        --format 'value(spec.template.spec.serviceAccountName)')

    if [[ -n "$service_account" ]]; then
        gsutil iam ch "serviceAccount:${service_account}:objectViewer" "gs://${CONFIG_BUCKET}" || {
            log_warn "Failed to grant bucket permissions to service account"
        }
    fi

    # Enable required APIs
    gcloud services enable \
        run.googleapis.com \
        containerregistry.googleapis.com \
        cloudbuild.googleapis.com \
        logging.googleapis.com \
        monitoring.googleapis.com \
        secretmanager.googleapis.com || {
        log_warn "Some APIs failed to enable"
    }
}

main() {
    log_info "Starting MI-SOAR-NGFW Cloud Run deployment"

    check_dependencies
    validate_environment
    build_and_push_image
    upload_configs
    setup_iam
    deploy_to_cloudrun

    log_info "Deployment completed successfully!"
    log_info "Next steps:"
    log_info "1. Configure custom domain in Cloud Run"
    log_info "2. Set up SSL certificates"
    log_info "3. Configure monitoring alerts"
    log_info "4. Test the deployment with health checks"
}

# Run main function
main "$@"