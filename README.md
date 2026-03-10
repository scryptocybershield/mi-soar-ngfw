# MI-SOAR-NGFW: Next-Generation Firewall with SOAR Capabilities

[![Integration Tests](https://github.com/scryptocybershield/mi-soar-ngfw/actions/workflows/test-integration.yml/badge.svg)](https://github.com/scryptocybershield/mi-soar-ngfw/actions/workflows/test-integration.yml)
[![Deploy to GCP Cloud Run](https://github.com/scryptocybershield/mi-soar-ngfw/actions/workflows/deploy-gcp-cloudrun.yml/badge.svg)](https://github.com/scryptocybershield/mi-soar-ngfw/actions/workflows/deploy-gcp-cloudrun.yml)
[![Security Scan](https://github.com/scryptocybershield/mi-soar-ngfw/actions/workflows/test-integration.yml/badge.svg?branch=main&event=push)](https://github.com/scryptocybershield/mi-soar-ngfw/actions/workflows/test-integration.yml)

A comprehensive, production-ready Next-Generation Firewall (NGFW) platform integrated with Security Orchestration, Automation, and Response (SOAR) capabilities. Deployable across hybrid environments: local VirtualBox, Google Cloud Platform (GCP), and OVH.

## Architecture Overview

MI-SOAR-NGFW is a multi-container platform built with Docker Compose, featuring:

- **Suricata**: IDS/IPS with real-time threat detection
- **WireGuard**: Secure VPN with automated peer management
- **nftables**: Modern firewall with dynamic rule management
- **Wazuh**: SIEM with centralized logging and alerting
- **n8n**: SOAR workflow automation with custom security nodes
- **Traefik**: Reverse proxy with SSL termination and load balancing

### Hybrid Deployment Support
- **Local Development**: VirtualBox with Docker Compose
- **Cloud Run**: Serverless container deployment on GCP
- **Compute Engine**: VM-based deployment on GCP
- **OVH**: Compatible with OVH cloud infrastructure

## Quick Start

### Prerequisites
- Docker Engine 20.10+
- Docker Compose 2.0+
- Git
- 8GB RAM minimum, 16GB recommended

### Local Deployment (VirtualBox/Development)

1. Clone the repository:
```bash
git clone https://github.com/scryptocybershield/mi-soar-ngfw.git
cd mi-soar-ngfw
```

2. Copy environment template:
```bash
cp .env.example .env
# Edit .env with your configuration
```

3. Start the platform:
```bash
docker-compose -f docker-compose.yml -f docker-compose.local.yml up -d
```

4. Verify deployment:
```bash
./scripts/monitoring/health-checks.sh
```

5. Access services:
- **Traefik Dashboard**: http://localhost:8080
- **n8n**: http://localhost:5678
- **Wazuh Dashboard**: http://localhost:5601 (if enabled)

### GCP Cloud Run Deployment

1. Set up Google Cloud SDK and authenticate:
```bash
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
```

2. Run deployment script:
```bash
export PROJECT_ID=your-project-id
./scripts/deploy/gcp-cloudrun.sh
```

3. The script will:
   - Build and push Docker image to Google Container Registry
   - Upload configurations to Cloud Storage
   - Deploy to Cloud Run with proper IAM permissions
   - Output the service URL

### GCP Compute Engine Deployment

1. Configure environment:
```bash
export PROJECT_ID=your-project-id
export ZONE=europe-west1-b
```

2. Deploy to GCE:
```bash
./scripts/deploy/gcp-gce.sh
```

3. The script will:
   - Create a Compute Engine VM with optimized configuration
   - Install Docker and dependencies
   - Copy application files and start services
   - Configure firewall rules and monitoring

## Configuration

### Environment Variables

Key environment variables (see `.env.example` for complete list):

| Variable | Description | Default |
|----------|-------------|---------|
| `SURICATA_IFACE` | Network interface for Suricata | `eth0` |
| `WG_SERVER_PORT` | WireGuard UDP port | `51820` |
| `WG_PEERS` | Number of WireGuard peers | `10` |
| `WAZUH_API_USER` | Wazuh API username | `wazuh` |
| `WAZUH_API_PASSWORD` | Wazuh API password | `changeme` |
| `N8N_ENCRYPTION_KEY` | n8n encryption key | `changeme` |
| `LOG_LEVEL` | Application log level | `info` |

### Service Configuration

Configuration files are organized in `configs/` directory:

```
configs/
├── suricata/          # IDS/IPS rules and configuration
├── wireguard/         # VPN server configuration
├── nftables/          # Firewall rules
├── wazuh/             # SIEM configuration
├── n8n/               # SOAR workflow configuration
└── traefik/           # Reverse proxy configuration
```

### Customizing Rules

1. **Suricata Rules**: Edit `configs/suricata/suricata.rules`
2. **nftables Rules**: Edit `configs/nftables/main.nft`
3. **Wazuh Rules**: Add custom rules to `configs/wazuh/rules/`
4. **n8n Workflows**: Create workflows in n8n UI or export to `configs/n8n/workflows/`

## Platform Features

### Threat Detection & Prevention
- Real-time network traffic analysis with Suricata
- Signature-based and anomaly-based detection
- Automated blocking via nftables integration
- Custom rule sets for application-layer protection

### Secure Remote Access
- WireGuard VPN with automated peer provisioning
- Certificate-based authentication
- Dynamic firewall rules for VPN clients
- Integration with n8n for access request workflows

### Security Orchestration
- n8n workflows for automated incident response
- Custom nodes for Suricata, Wazuh, nftables, WireGuard
- Webhook integration with security tools
- Playbook execution for common threats

### Centralized Monitoring
- Wazuh SIEM for log aggregation and correlation
- Real-time dashboards and alerting
- Compliance monitoring (PCI DSS, GDPR, etc.)
- Integration with external ticketing systems

### High Availability
- Docker-based container orchestration
- Health checks and auto-restart
- Persistent storage for configurations and logs
- Blue-green deployment support for GCE

## Verification & Testing

### Component Verification
Each component includes validation commands:

```bash
# Suricata configuration
suricata -T -c configs/suricata/suricata.yaml

# nftables rules
nft --check -f configs/nftables/main.nft

# WireGuard connectivity
wg-quick up configs/wireguard/wg0.conf

# Wazuh configuration
wazuh-manager -t -c configs/wazuh/ossec.conf

# Docker Compose validation
docker-compose config
```

### Health Checks
Run comprehensive health checks:
```bash
./scripts/monitoring/health-checks.sh
```

### Integration Tests
GitHub Actions automatically run:
1. Unit tests for configurations
2. Integration tests with Docker Compose
3. Security vulnerability scanning
4. Performance testing

## Deployment Strategies

### Development (VirtualBox)
- Use `docker-compose.local.yml` overrides
- Reduced resource requirements
- Local volume mounts for easy configuration updates
- No external dependencies

### Staging (GCP Cloud Run)
- Serverless container deployment
- Automatic scaling
- Pay-per-use pricing model
- Easy rollback with container versions

### Production (GCP Compute Engine)
- Dedicated VM resources
- Persistent storage
- Load balancer integration
- Backup and disaster recovery options

### Production (OVH)
- Compatible with OVH cloud infrastructure
- Similar deployment patterns to GCP
- Custom networking configuration

## Security Considerations

### Principle of Least Privilege
- Containers run as non-root users
- Granular capability assignment (NET_ADMIN, NET_RAW)
- Separate Docker networks for service isolation
- Read-only configuration mounts where possible

### Network Security
- Internal Docker network for service communication
- Host network only for Suricata and WireGuard
- Network policies between containers
- Mutual TLS for internal APIs

### Secret Management
- Environment variables for sensitive data
- .env file excluded from version control
- Cloud-native secret managers (Cloud Secret Manager, etc.)
- Encryption at rest for sensitive configurations

### Compliance
- Regular vulnerability scanning with Trivy
- Secret detection with TruffleHog
- Configuration hardening scripts
- Audit logging for all security events

## Maintenance

### Updates
1. **Security Updates**: Regular base image updates
2. **Rule Updates**: Automated Suricata rule updates
3. **Configuration Updates**: Version-controlled configs
4. **Platform Updates**: Rolling updates with health checks

### Monitoring
- Built-in health checks for all services
- Cloud Monitoring integration (GCP)
- Centralized logging with Wazuh
- Alerting via email, webhooks, or ticketing systems

### Backup & Recovery
- Regular backups of configurations
- Persistent volume backups
- Disaster recovery procedures
- Configuration versioning

## Troubleshooting

### Common Issues

1. **Suricata not starting**: Check network interface permissions and capabilities
2. **WireGuard connection issues**: Verify firewall rules and port forwarding
3. **n8n workflow errors**: Check webhook URLs and API permissions
4. **High resource usage**: Adjust container resource limits in compose files

### Logs
Access logs for each service:
```bash
# Docker container logs
docker-compose logs [service_name]

# Application logs
tail -f storage/logs/[service]/[logfile]
```

### Support
- GitHub Issues for bug reports and feature requests
- Documentation in `/docs` directory
- Example configurations in `/configs/examples`

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes with comprehensive tests
4. Submit a pull request

See `CONTRIBUTING.md` for detailed guidelines.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- [Suricata](https://suricata.io/) - Network threat detection engine
- [WireGuard](https://www.wireguard.com/) - Modern VPN protocol
- [Wazuh](https://wazuh.com/) - Open source SIEM
- [n8n](https://n8n.io/) - Workflow automation platform
- [Traefik](https://traefik.io/) - Cloud-native application proxy

---

**Disclaimer**: This platform is designed for educational and research purposes. Implement appropriate security controls and compliance measures for production deployments.