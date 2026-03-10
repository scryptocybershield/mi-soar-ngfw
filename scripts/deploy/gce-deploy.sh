#!/bin/bash
# GCE Deployment Script for MI-SOAR-NGFW
# Runs on the VM instance to deploy the application

set -euo pipefail

# Configuration
APP_DIR="/opt/mi-soar-ngfw"
CONFIG_DIR="/etc/mi-soar-ngfw"
LOG_DIR="/var/log/mi-soar-ngfw"
USER="mi-soar-ngfw"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log "Checking prerequisites..."

    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi

    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose is not installed"
        exit 1
    fi

    # Check if Docker is running
    if ! systemctl is-active --quiet docker; then
        log_error "Docker daemon is not running"
        exit 1
    fi

    log_success "All prerequisites met"
}

setup_directories() {
    log "Setting up directories..."

    # Create directories
    sudo mkdir -p "$APP_DIR"
    sudo mkdir -p "$CONFIG_DIR"
    sudo mkdir -p "$LOG_DIR"

    # Copy application files if they exist in /tmp
    if [[ -d "/tmp/mi-soar-ngfw" ]]; then
        log "Copying application files from /tmp..."
        sudo cp -r /tmp/mi-soar-ngfw/* "$APP_DIR/"
    fi

    # Set permissions
    sudo chown -R root:root "$APP_DIR"
    sudo chmod -R 755 "$APP_DIR"
    sudo find "$APP_DIR" -type f -exec chmod 644 {} \;
    sudo find "$APP_DIR" -name "*.sh" -exec chmod 755 {} \;

    sudo chown -R root:root "$CONFIG_DIR"
    sudo chmod -R 755 "$CONFIG_DIR"

    sudo chown -R root:root "$LOG_DIR"
    sudo chmod -R 755 "$LOG_DIR"

    log_success "Directories set up"
}

configure_environment() {
    log "Configuring environment..."

    # Create .env file if it doesn't exist
    if [[ ! -f "$APP_DIR/.env" ]]; then
        log "Creating .env file from template..."
        sudo cp "$APP_DIR/.env.example" "$APP_DIR/.env"
        log_warning "Please edit $APP_DIR/.env with your configuration"
    fi

    # Set environment variables
    if [[ -f "$APP_DIR/.env" ]]; then
        set -o allexport
        source "$APP_DIR/.env"
        set +o allexport
    fi

    log_success "Environment configured"
}

setup_docker_networks() {
    log "Setting up Docker networks..."

    # Create the mi-soar-network if it doesn't exist
    if ! docker network inspect mi-soar-network > /dev/null 2>&1; then
        docker network create \
          --driver bridge \
          --subnet=10.10.0.0/24 \
          mi-soar-network
        log_success "Docker network 'mi-soar-network' created"
    else
        log "Docker network 'mi-soar-network' already exists"
    fi

    # Check host network
    if [[ ! -d /sys/class/net/host ]]; then
        log_warning "Host network namespace not found"
    fi
}

deploy_services() {
    log "Deploying services..."

    # Change to application directory
    cd "$APP_DIR"

    # Stop any existing services
    if [[ -f "docker-compose.yml" ]]; then
        log "Stopping existing services..."
        docker-compose down || true
    fi

    # Start services with production configuration
    log "Starting services with production configuration..."

    # Check which compose files exist
    COMPOSE_FILES="-f docker-compose.yml"
    if [[ -f "docker-compose.prod.yml" ]]; then
        COMPOSE_FILES="$COMPOSE_FILES -f docker-compose.prod.yml"
    fi

    # Deploy
    docker-compose $COMPOSE_FILES up -d --remove-orphans

    # Wait for services to start
    log "Waiting for services to start..."
    sleep 30

    # Check service status
    log "Checking service status..."
    docker-compose ps

    log_success "Services deployed"
}

configure_firewall() {
    log "Configuring firewall..."

    # Check if nftables is installed
    if command -v nft &> /dev/null; then
        # Load nftables rules from config
        if [[ -f "$APP_DIR/configs/nftables/main.nft" ]]; then
            log "Loading nftables rules..."
            nft --check -f "$APP_DIR/configs/nftables/main.nft" || {
                log_warning "nftables rules validation failed"
                return
            }
            nft -f "$APP_DIR/configs/nftables/main.nft" || {
                log_warning "Failed to load nftables rules"
                return
            }
            log_success "nftables rules loaded"
        fi
    else
        log_warning "nftables not installed, skipping firewall configuration"
    fi

    # Configure iptables for Docker
    iptables -P FORWARD ACCEPT || log_warning "Failed to set FORWARD policy"
}

setup_logging() {
    log "Setting up logging..."

    # Create logrotate configuration
    sudo tee /etc/logrotate.d/mi-soar-ngfw > /dev/null << EOF
$LOG_DIR/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
}
EOF

    log_success "Logging configured"
}

setup_monitoring() {
    log "Setting up monitoring..."

    # Create health check cron job
    sudo tee /etc/cron.d/mi-soar-ngfw-healthcheck > /dev/null << EOF
# MI-SOAR-NGFW Health Checks
*/5 * * * * root $APP_DIR/scripts/monitoring/health-checks.sh >> $LOG_DIR/health-checks.log 2>&1
EOF

    log_success "Monitoring configured"
}

verify_deployment() {
    log "Verifying deployment..."

    # Run health checks
    if [[ -f "$APP_DIR/scripts/monitoring/health-checks.sh" ]]; then
        log "Running health checks..."
        "$APP_DIR/scripts/monitoring/health-checks.sh" || {
            log_warning "Health checks reported issues"
        }
    else
        log_warning "Health check script not found"
    fi

    # Check essential services
    log "Checking essential services..."
    for service in suricata wireguard wazuh n8n; do
        if docker ps --format '{{.Names}}' | grep -q "$service"; then
            log_success "$service container is running"
        else
            log_warning "$service container is not running"
        fi
    done

    log_success "Deployment verification completed"
}

main() {
    log "Starting MI-SOAR-NGFW GCE deployment"

    # Check prerequisites
    check_prerequisites

    # Set up directories
    setup_directories

    # Configure environment
    configure_environment

    # Set up Docker networks
    setup_docker_networks

    # Deploy services
    deploy_services

    # Configure firewall
    configure_firewall

    # Set up logging
    setup_logging

    # Set up monitoring
    setup_monitoring

    # Verify deployment
    verify_deployment

    log_success "MI-SOAR-NGFW deployment completed successfully!"
    log ""
    log "Next steps:"
    log "1. Access the platform:"
    log "   - Traefik Dashboard: http://$(hostname -I | awk '{print $1}'):8080"
    log "   - n8n: http://$(hostname -I | awk '{print $1}'):5678"
    log "2. Configure credentials in $APP_DIR/.env"
    log "3. Review logs: $LOG_DIR/"
    log "4. Set up backups and monitoring"
    log ""
    log "For support, check the documentation in $APP_DIR/docs/"
}

# Run main function
main "$@"