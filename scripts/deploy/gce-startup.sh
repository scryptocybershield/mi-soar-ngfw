#!/bin/bash
# GCE Startup Script for MI-SOAR-NGFW
# Runs on VM instance creation

set -euo pipefail

# Configuration
PROJECT_ID="${1:-}"
INSTANCE_NAME=$(curl -s -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/name")
ZONE=$(curl -s -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/zone" | cut -d/ -f4)

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

update_system() {
    log "Updating system packages..."
    apt-get update -y
    apt-get upgrade -y
}

install_dependencies() {
    log "Installing dependencies..."

    # Install Docker
    if ! command -v docker &> /dev/null; then
        apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
        curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
        apt-get update -y
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    fi

    # Install gcloud CLI (for config management)
    if ! command -v gcloud &> /dev/null; then
        echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" > /etc/apt/sources.list.d/google-cloud-sdk.list
        curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
        apt-get update -y
        apt-get install -y google-cloud-sdk
    fi

    # Install monitoring agent
    curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
    bash add-google-cloud-ops-agent-repo.sh --also-install
}

configure_docker() {
    log "Configuring Docker..."

    # Enable Docker to start on boot
    systemctl enable docker
    systemctl start docker

    # Allow current user to run Docker commands
    usermod -aG docker "$(whoami)"

    # Configure Docker daemon
    cat > /etc/docker/daemon.json << EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "live-restore": true
}
EOF

    systemctl restart docker
}

setup_application_directory() {
    log "Setting up application directory..."

    # Create application directory
    mkdir -p /opt/mi-soar-ngfw
    chmod 755 /opt/mi-soar-ngfw

    # Copy application files if they exist in /tmp
    if [[ -d "/tmp/mi-soar-ngfw" ]]; then
        cp -r /tmp/mi-soar-ngfw/* /opt/mi-soar-ngfw/
    fi

    # Set permissions
    chown -R root:root /opt/mi-soar-ngfw
    chmod -R 644 /opt/mi-soar-ngfw
    find /opt/mi-soar-ngfw -type d -exec chmod 755 {} \;
    find /opt/mi-soar-ngfw -name "*.sh" -exec chmod 755 {} \;
}

configure_networking() {
    log "Configuring networking..."

    # Enable IP forwarding
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.all.forwarding = 1" >> /etc/sysctl.conf
    sysctl -p

    # Configure iptables for Docker
    iptables -P FORWARD ACCEPT
}

create_systemd_service() {
    log "Creating systemd service..."

    cat > /etc/systemd/system/mi-soar-ngfw.service << EOF
[Unit]
Description=MI-SOAR-NGFW Security Platform
Requires=docker.service
After=docker.service network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/mi-soar-ngfw
ExecStart=/usr/bin/docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --remove-orphans
ExecStop=/usr/bin/docker compose -f docker-compose.yml -f docker-compose.prod.yml down
ExecReload=/usr/bin/docker compose -f docker-compose.yml -f docker-compose.prod.yml restart
TimeoutStartSec=0
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    # Also create a timer for periodic health checks
    cat > /etc/systemd/system/mi-soar-ngfw-healthcheck.timer << EOF
[Unit]
Description=Run MI-SOAR-NGFW health check every 5 minutes

[Timer]
OnBootSec=5min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
EOF

    cat > /etc/systemd/system/mi-soar-ngfw-healthcheck.service << EOF
[Unit]
Description=MI-SOAR-NGFW Health Check

[Service]
Type=oneshot
WorkingDirectory=/opt/mi-soar-ngfw
ExecStart=/opt/mi-soar-ngfw/scripts/monitoring/health-checks.sh
EOF

    systemctl daemon-reload
    systemctl enable mi-soar-ngfw.service
    systemctl enable mi-soar-ngfw-healthcheck.timer
}

setup_logging() {
    log "Setting up logging..."

    # Create log directory
    mkdir -p /var/log/mi-soar-ngfw
    chmod 755 /var/log/mi-soar-ngfw

    # Configure logrotate
    cat > /etc/logrotate.d/mi-soar-ngfw << EOF
/var/log/mi-soar-ngfw/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
    sharedscripts
    postrotate
        systemctl reload mi-soar-ngfw > /dev/null 2>&1 || true
    endscript
}
EOF
}

main() {
    log "Starting MI-SOAR-NGFW GCE startup script"

    # Update system
    update_system

    # Install dependencies
    install_dependencies

    # Configure Docker
    configure_docker

    # Set up application directory
    setup_application_directory

    # Configure networking
    configure_networking

    # Create systemd service
    create_systemd_service

    # Set up logging
    setup_logging

    # Start the service
    log "Starting MI-SOAR-NGFW service..."
    systemctl start mi-soar-ngfw.service
    systemctl start mi-soar-ngfw-healthcheck.timer

    log "Startup script completed successfully"
    log "Instance: $INSTANCE_NAME"
    log "Zone: $ZONE"
    log "Project: $PROJECT_ID"
}

# Run main function
main "$@"