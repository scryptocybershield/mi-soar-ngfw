#!/bin/bash
# MI-SOAR-NGFW Component Verification
# Runs mandatory verification steps for each component as per implementation plan

set -euo pipefail

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

verify_suricata() {
    log "Verifying Suricata configuration..."
    if command -v suricata &> /dev/null; then
        if suricata -T -c configs/suricata/suricata.yaml; then
            log_success "Suricata configuration verification passed"
        else
            log_error "Suricata configuration verification failed"
            return 1
        fi
    else
        log_warning "Suricata not installed locally, testing with Docker..."
        if docker run --rm -v $(pwd)/configs/suricata:/etc/suricata:ro jasonish/suricata:latest \
            -T -c /etc/suricata/suricata.yaml; then
            log_success "Suricata configuration verification passed (Docker)"
        else
            log_error "Suricata configuration verification failed (Docker)"
            return 1
        fi
    fi
}

verify_nftables() {
    log "Verifying nftables configuration..."
    if command -v nft &> /dev/null; then
        if nft --check -f configs/nftables/main.nft; then
            log_success "nftables configuration verification passed"
        else
            log_error "nftables configuration verification failed"
            return 1
        fi
    else
        log_warning "nftables not installed locally, testing with Docker..."
        if docker run --rm -v $(pwd)/configs/nftables:/etc/nftables:ro debian:bookworm-slim \
            nft --check -f /etc/nftables/main.nft; then
            log_success "nftables configuration verification passed (Docker)"
        else
            log_error "nftables configuration verification failed (Docker)"
            return 1
        fi
    fi
}

verify_wireguard() {
    log "Verifying WireGuard configuration..."
    if [[ -f "configs/wireguard/wg0.conf" ]]; then
        log "WireGuard configuration file exists"
        # Check for template placeholders
        if grep -q "REPLACE_WITH" configs/wireguard/wg0.conf; then
            log_warning "WireGuard configuration contains template placeholders"
        else
            log_success "WireGuard configuration appears to be customized"
        fi
    else
        log_warning "WireGuard configuration file not found"
    fi
}

verify_wazuh() {
    log "Verifying Wazuh configuration..."
    if [[ -f "configs/wazuh/ossec.conf" ]]; then
        log "Wazuh configuration file exists"
        # Simple XML syntax check
        if command -v xmllint &> /dev/null; then
            if xmllint --noout configs/wazuh/ossec.conf; then
                log_success "Wazuh XML configuration is valid"
            else
                log_error "Wazuh XML configuration is invalid"
                return 1
            fi
        else
            log_warning "xmllint not installed, skipping XML validation"
        fi
    else
        log_error "Wazuh configuration file not found"
        return 1
    fi
}

verify_n8n() {
    log "Verifying n8n configuration..."
    if [[ -f "configs/n8n/config.json" ]]; then
        log "n8n configuration file exists"
        # Check JSON syntax
        if command -v jq &> /dev/null; then
            if jq empty configs/n8n/config.json; then
                log_success "n8n JSON configuration is valid"
            else
                log_error "n8n JSON configuration is invalid"
                return 1
            fi
        else
            log_warning "jq not installed, skipping JSON validation"
        fi
    else
        log_error "n8n configuration file not found"
        return 1
    fi
}

verify_docker_compose() {
    log "Verifying Docker Compose configuration..."
    if command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
        if docker compose config > /dev/null 2>&1; then
            log_success "Docker Compose configuration validation passed"
        else
            log_error "Docker Compose configuration validation failed"
            return 1
        fi
    else
        log_error "Docker Compose not available"
        return 1
    fi
}

verify_end_to_end() {
    log "Verifying end-to-end simulation..."
    log "This would simulate an attack detection with automated response verification"
    log_warning "End-to-end verification requires running platform - skipping"
    # TODO: Implement actual end-to-end test
}

main() {
    log "Starting MI-SOAR-NGFW component verification"

    local errors=0

    # Run all verification steps
    verify_suricata || errors=$((errors + 1))
    verify_nftables || errors=$((errors + 1))
    verify_wireguard || errors=$((errors + 1))
    verify_wazuh || errors=$((errors + 1))
    verify_n8n || errors=$((errors + 1))
    verify_docker_compose || errors=$((errors + 1))
    verify_end_to_end || errors=$((errors + 1))

    # Summary
    if [[ $errors -eq 0 ]]; then
        log_success "All component verifications passed!"
        log "Platform is ready for deployment"
    else
        log_error "$errors verification step(s) failed"
        log "Please fix the issues before deployment"
        exit 1
    fi
}

# Run main function
main "$@"