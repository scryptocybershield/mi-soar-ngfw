# Changelog

All notable changes to MI-SOAR-NGFW will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial project structure and foundation
- Multi-container Docker Compose architecture
- Configuration files for all core services:
  - Suricata IDS/IPS with nftables integration
  - WireGuard VPN server
  - nftables firewall with dynamic rule management
  - Wazuh SIEM (single-node deployment)
  - n8n SOAR workflow automation
  - Traefik reverse proxy with SSL termination
- Deployment scripts for:
  - Local VirtualBox development
  - GCP Cloud Run (serverless)
  - GCP Compute Engine (VM-based)
- GitHub Actions CI/CD pipelines:
  - Automated testing and validation
  - Security scanning with Trivy and TruffleHog
  - Deployment to GCP Cloud Run and Compute Engine
- Comprehensive documentation:
  - Architecture overview and design decisions
  - Deployment guides for all target environments
  - Contributing guidelines and code of conduct
  - Verification and testing procedures
- Security hardening scripts
- Health check and monitoring system
- Custom n8n nodes placeholder for security automation

### Technical Specifications
- Base image: Debian bookworm-slim
- Container orchestration: Docker Compose 3.8
- Network architecture: Host network for security services, internal bridge for management
- Security: Principle of least privilege, non-root containers, capability restrictions
- Storage: Persistent volumes for logs, configurations, and rule sets
- Monitoring: Built-in health checks, Cloud Monitoring integration, centralized logging

### Configuration Features
- Environment variable based configuration (.env)
- Development, staging, and production profiles
- Automated configuration validation
- Rule versioning and rollback capability
- Integrated service discovery and load balancing

### Deployment Options
1. **Local Development**: VirtualBox with Docker Compose
2. **Cloud Run**: Serverless container deployment on GCP
3. **Compute Engine**: VM-based deployment on GCP
4. **OVH Cloud**: Compatible with OVH cloud infrastructure

### Verification Steps Implemented
- Suricata configuration validation (`suricata -T`)
- nftables syntax checking (`nft --check`)
- WireGuard configuration template
- Wazuh XML configuration validation
- n8n JSON configuration validation
- Docker Compose configuration validation
- Comprehensive health checks for all services

## [1.0.0] - 2026-03-10

### Initial Release
- Complete NGFW+SOAR platform foundation
- All core services integrated and configurable
- Automated deployment pipelines
- Production-ready configurations
- Security hardening baseline

### Known Issues
- Suricata verification in Docker requires writable volume (configuration is valid)
- nftables interface validation warnings (interfaces defined as placeholders)
- Some verification steps require external dependencies

### Next Steps
1. Testing and validation in target environments
2. Performance tuning and optimization
3. Additional cloud provider support
4. Enhanced monitoring and alerting
5. Community feedback and contributions