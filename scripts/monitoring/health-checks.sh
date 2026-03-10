#!/bin/bash
# MI-SOAR-NGFW Health Checks
# Comprehensive health verification for all platform components

set -euo pipefail

# Configuration
LOG_FILE="/var/log/mi-soar-ngfw/health-checks.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
RETCODE=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "[$TIMESTAMP] $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    RETCODE=1
}

check_docker() {
    log "Checking Docker daemon..."
    if systemctl is-active --quiet docker; then
        log_success "Docker daemon is running"
    else
        log_error "Docker daemon is not running"
        return
    fi

    # Check Docker containers
    local running_containers=$(docker ps --format '{{.Names}}' | wc -l)
    local total_containers=$(docker ps -a --format '{{.Names}}' | wc -l)

    if [[ "$running_containers" -eq "$total_containers" ]]; then
        log_success "All containers are running ($running_containers/$total_containers)"
    else
        log_warning "Some containers are not running ($running_containers/$total_containers)"
        docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | tee -a "$LOG_FILE"
    fi
}

check_suricata() {
    log "Checking Suricata..."
    if docker ps --format '{{.Names}}' | grep -q "mi-soar-suricata"; then
        # Check if Suricata is processing traffic
        local suricata_pid=$(docker exec mi-soar-suricata pgrep suricata | head -1)
        if [[ -n "$suricata_pid" ]]; then
            log_success "Suricata is running (PID: $suricata_pid)"
        else
            log_error "Suricata process not found in container"
        fi

        # Check Suricata stats
        if docker exec mi-soar-suricata suricatasc -c uptime > /dev/null 2>&1; then
            log_success "Suricata control socket is responsive"
        else
            log_warning "Suricata control socket not responsive"
        fi
    else
        log_error "Suricata container not found"
    fi
}

check_wireguard() {
    log "Checking WireGuard..."
    if docker ps --format '{{.Names}}' | grep -q "mi-soar-wireguard"; then
        # Check WireGuard interface
        if docker exec mi-soar-wireguard wg show > /dev/null 2>&1; then
            local peer_count=$(docker exec mi-soar-wireguard wg show | grep -c "peer:")
            log_success "WireGuard is running with $peer_count peer(s)"
        else
            log_error "WireGuard interface not configured"
        fi
    else
        log_error "WireGuard container not found"
    fi
}

check_nftables() {
    log "Checking nftables..."
    if docker ps --format '{{.Names}}' | grep -q "mi-soar-nftables"; then
        # Check if nftables rules are loaded
        if docker exec mi-soar-nftables nft list ruleset > /dev/null 2>&1; then
            local rule_count=$(docker exec mi-soar-nftables nft list ruleset | wc -l)
            log_success "nftables rules loaded ($rule_count lines)"
        else
            log_error "nftables rules not loaded"
        fi
    else
        log_error "nftables container not found"
    fi
}

check_wazuh() {
    log "Checking Wazuh..."
    if docker ps --format '{{.Names}}' | grep -q "mi-soar-wazuh"; then
        # Check Wazuh API
        if docker exec mi-soar-wazuh curl -s -f http://localhost:55000 > /dev/null 2>&1; then
            log_success "Wazuh API is responsive"
        else
            log_error "Wazuh API not responsive"
        fi

        # Check Wazuh manager status
        if docker exec mi-soar-wazuh /var/ossec/bin/wazuh-control status > /dev/null 2>&1; then
            log_success "Wazuh manager is running"
        else
            log_warning "Wazuh manager may have issues"
        fi
    else
        log_error "Wazuh container not found"
    fi
}

check_n8n() {
    log "Checking n8n..."
    if docker ps --format '{{.Names}}' | grep -q "mi-soar-n8n"; then
        # Check n8n health endpoint
        if docker exec mi-soar-n8n curl -s -f http://localhost:5678/healthz > /dev/null 2>&1; then
            log_success "n8n is responsive"
        else
            log_error "n8n health check failed"
        fi

        # Check workflow count
        local workflow_count=$(docker exec mi-soar-n8n find /home/node/.n8n/workflows -name "*.json" 2>/dev/null | wc -l)
        log "n8n has $workflow_count workflow(s)"
    else
        log_error "n8n container not found"
    fi
}

check_traefik() {
    log "Checking Traefik..."
    if docker ps --format '{{.Names}}' | grep -q "mi-soar-traefik"; then
        # Check Traefik API
        if docker exec mi-soar-traefik curl -s -f http://localhost:8080/api/rawdata > /dev/null 2>&1; then
            log_success "Traefik API is responsive"
        else
            log_error "Traefik API not responsive"
        fi
    else
        log_error "Traefik container not found"
    fi
}

check_resources() {
    log "Checking system resources..."

    # CPU load
    local load=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
    local cores=$(nproc)
    if (( $(echo "$load > $cores * 0.8" | bc -l) )); then
        log_warning "High CPU load: $load (cores: $cores)"
    else
        log_success "CPU load: $load (cores: $cores)"
    fi

    # Memory
    local free_mem=$(free -m | awk '/^Mem:/{print $4}')
    local total_mem=$(free -m | awk '/^Mem:/{print $2}')
    local mem_percent=$(( (total_mem - free_mem) * 100 / total_mem ))
    if [[ "$mem_percent" -gt 90 ]]; then
        log_warning "High memory usage: ${mem_percent}%"
    else
        log_success "Memory usage: ${mem_percent}%"
    fi

    # Disk space
    local disk_usage=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
    if [[ "$disk_usage" -gt 90 ]]; then
        log_warning "High disk usage: ${disk_usage}%"
    else
        log_success "Disk usage: ${disk_usage}%"
    fi
}

check_network() {
    log "Checking network connectivity..."

    # Check internet connectivity
    if ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1; then
        log_success "Internet connectivity OK"
    else
        log_warning "Internet connectivity issue"
    fi

    # Check Docker network
    if docker network inspect mi-soar-network > /dev/null 2>&1; then
        log_success "Docker network 'mi-soar-network' exists"
    else
        log_warning "Docker network 'mi-soar-network' not found"
    fi
}

check_logs() {
    log "Checking for recent errors in logs..."

    # Check Docker logs for errors (last 15 minutes)
    local error_count=0
    for container in $(docker ps --format '{{.Names}}'); do
        local container_errors=$(docker logs --since 15m "$container" 2>&1 | grep -i -E "error|fail|exception|critical" | wc -l)
        if [[ "$container_errors" -gt 0 ]]; then
            log_warning "$container has $container_errors error(s) in last 15 minutes"
            error_count=$((error_count + container_errors))
        fi
    done

    if [[ "$error_count" -eq 0 ]]; then
        log_success "No recent errors found in container logs"
    fi
}

main() {
    log "Starting MI-SOAR-NGFW health checks..."

    # Create log directory if it doesn't exist
    mkdir -p "$(dirname "$LOG_FILE")"

    # Run all checks
    check_docker
    check_suricata
    check_wireguard
    check_nftables
    check_wazuh
    check_n8n
    check_traefik
    check_resources
    check_network
    check_logs

    # Summary
    if [[ "$RETCODE" -eq 0 ]]; then
        log_success "All health checks passed"
    else
        log_error "Some health checks failed"
    fi

    log "Health checks completed at $(date)"
    exit $RETCODE
}

# Run main function
main "$@"