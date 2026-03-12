# MI-SOAR-NGFW: Next-Generation Firewall with SOAR Capabilities

[![CI](https://github.com/scryptocybershield/mi-soar-ngfw/actions/workflows/ci.yml/badge.svg)](https://github.com/scryptocybershield/mi-soar-ngfw/actions/workflows/ci.yml)
[![Deploy to GCP Cloud Run](https://github.com/scryptocybershield/mi-soar-ngfw/actions/workflows/deploy-gcp-cloudrun.yml/badge.svg)](https://github.com/scryptocybershield/mi-soar-ngfw/actions/workflows/deploy-gcp-cloudrun.yml)
[![Security](https://github.com/scryptocybershield/mi-soar-ngfw/actions/workflows/security.yml/badge.svg)](https://github.com/scryptocybershield/mi-soar-ngfw/actions/workflows/security.yml)
[![Release Images](https://github.com/scryptocybershield/mi-soar-ngfw/actions/workflows/release-images.yml/badge.svg)](https://github.com/scryptocybershield/mi-soar-ngfw/actions/workflows/release-images.yml)
[![Promote Images](https://github.com/scryptocybershield/mi-soar-ngfw/actions/workflows/promote-images.yml/badge.svg)](https://github.com/scryptocybershield/mi-soar-ngfw/actions/workflows/promote-images.yml)
[![Rollback Images](https://github.com/scryptocybershield/mi-soar-ngfw/actions/workflows/rollback-images.yml/badge.svg)](https://github.com/scryptocybershield/mi-soar-ngfw/actions/workflows/rollback-images.yml)

A comprehensive, production-ready Next-Generation Firewall (NGFW) platform integrated with Security Orchestration, Automation, and Response (SOAR) capabilities. Deployable across hybrid environments: local VirtualBox, Google Cloud Platform (GCP), and OVH.

## Architecture Overview

MI-SOAR-NGFW is a multi-container platform built with Docker Compose, featuring:

- **Suricata**: IDS/IPS with real-time threat detection
- **WireGuard**: Secure VPN with automated peer management
- **OPNsense + OpenVPN (preferred lab path)**: real gateway enforcement with VPN tunnelled endpoints
- **nftables**: Modern firewall with dynamic rule management
- **Wazuh**: SIEM with centralized logging and alerting
- **n8n**: SOAR workflow automation with custom security nodes
- **Traefik**: Reverse proxy with SSL termination and load balancing

### Hybrid Deployment Support
- **Local Development**: VirtualBox with Docker Compose
- **Cloud Run**: Serverless container deployment on GCP
- **Compute Engine**: VM-based deployment on GCP
- **OVH**: Compatible with OVH cloud infrastructure

### Preferred SOAR Lab Path
- Use OPNsense as enforcement gateway and OpenVPN for endpoint tunnel ingress.
- Keep n8n as orchestration engine and Wazuh as detection/correlation.
- Keep `mock-firewall` for local mock mode and CI smoke tests.
- Blueprint: [opnsense-openvpn-lab.md](/home/s4lva/mi-soar-ngfw/docs/opnsense-openvpn-lab.md)
- Migration runbook: [opnsense-migration-runbook.md](/home/s4lva/mi-soar-ngfw/docs/opnsense-migration-runbook.md)
- SASE-like blueprint (control-plane/edge-plane): [sase-like-cato-blueprint.md](/home/s4lva/mi-soar-ngfw/docs/blueprints/sase-like-cato-blueprint.md)
- Policy API MVP (Sprint 1): [policy_api/README.md](/home/s4lva/mi-soar-ngfw/policy_api/README.md)
- Edge Agent MVP (Sprint 2): [edge_agent/README.md](/home/s4lva/mi-soar-ngfw/edge_agent/README.md)

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
- **Wazuh Dashboard**: https://localhost:5601
- **Mock Firewall API**: http://localhost:${MOCK_FIREWALL_PORT:-8081}
- **Firewall Dashboard**: http://localhost:${MOCK_FIREWALL_PORT:-8081}/dashboard
- **OPNsense Web UI (official, VM/appliance)**: https://<OPNSENSE_IP>/

6. Initialize Wazuh Indexer security (first start):
```bash
bash scripts/wazuh/init_indexer_security.sh
```

### Enable Wazuh -> n8n Webhook

After `docker compose up`, enable the Wazuh custom integration that forwards alerts to n8n:

```bash
bash scripts/wazuh/enable_n8n_webhook.sh
```

Optional environment overrides:

```bash
WAZUH_CONTAINER=mi-soar-wazuh \
WAZUH_N8N_HOOK_URL=http://n8n:5678/webhook/wazuh-alert \
WAZUH_N8N_MIN_LEVEL=5 \
bash scripts/wazuh/enable_n8n_webhook.sh
```

### Local Mock-First Deployment (Recommended)

Use this profile first to validate SOAR flows with mock data before enabling real firewall actions:

```bash
cp .env.example .env
docker compose -f docker-compose.yml -f docker-compose.local.yml up -d mock-firewall
curl -fsS http://localhost:${MOCK_FIREWALL_PORT:-8081}/healthz
```

Or with one-command targets:

```bash
make mock-up
make mock-health
make mock-test
```

Example flow:

```bash
curl -fsS -X POST http://localhost:${MOCK_FIREWALL_PORT:-8081}/block-ip \
  -H 'Content-Type: application/json' \
  -d '{"ip_address":"192.168.1.100","reason":"Brute force activity detected","duration_minutes":60,"vendor":"fortinet","created_by":"local-test"}'

curl -fsS http://localhost:${MOCK_FIREWALL_PORT:-8081}/blocked-ips
curl -fsS -X DELETE http://localhost:${MOCK_FIREWALL_PORT:-8081}/block-ip/192.168.1.100
```

Dashboard (rule management):
```bash
open http://localhost:${MOCK_FIREWALL_PORT:-8081}/dashboard
```

Use official OPNsense as external gateway/appliance (not a Docker container).
Set n8n integration vars to your OPNsense API endpoint and credentials:
```bash
OPNSENSE_BASE_URL=https://<OPNSENSE_IP>
OPNSENSE_API_KEY=...
OPNSENSE_API_SECRET=...
```

### Phase 1: Telegram ChatOps (Polling, Anti-dup)

This workflow avoids public Telegram webhooks (uses polling) and is suitable for local labs and VPS without public DNS.

1. Import workflow file in n8n:
```text
configs/n8n/workflows/telegram_chatops_firewall_commands_v1.json
```

2. Make sure these env vars are set for `n8n`:
```bash
TELEGRAM_BOT_TOKEN=...
FIREWALL_API_URL=http://mock-firewall:8080
TELEGRAM_ALLOWED_CHAT_IDS=123456789,987654321
POLICY_API_URL=http://policy-api:8080
POLICY_API_N8N_KEY=change-me-n8n
EDGE_NODE_ID=edge-lab-01
```

3. Activate the workflow (`telegram-chatops-firewall-commands-v2`) and keep only one Telegram polling workflow active to avoid duplicated responses.

Supported Telegram commands:
- `/help`
- `/status`
- `/status <action_id>` (consulta en `policy-api`)
- `/list` (bloqueos activos desde `policy-api`)
- `/rules`
- `/block <ip> [minutes]`
- `/unblock <ip>`
- `/applyrule <rule_id>`
- `/flush` (clear pending queue + dedup state)
- `/resetcursor` (reset per-chat cursor)

Examples:
```text
/block 203.0.113.10 120
/unblock 203.0.113.10
/rules
/applyrule rule-abc123
/status
/status 28ac17be-92ee-4ff7-bd4e-d0ab5fd2e7d0
/flush
```

Note for `/block`, `/unblock` and `/list`:
- `/block` now creates an **accepted action** in `policy-api` (`POST /actions/block-ip`).
- `/unblock` now creates an **accepted action** in `policy-api` (`POST /actions/unblock-ip`).
- `/list` now reads active blocks from control plane (`GET /edge-nodes/{edge_node_id}/blocks`).
- Actual enforcement is applied later by `edge-agent` polling and updating `nftables`.
- In local compose, `policy-api` is exposed on `http://localhost:8090/healthz` for verification.

### Realtime Chatbot Mode (No Cron)

For immediate responses (chatbot style), use:
```text
configs/n8n/workflows/telegram_chatops_firewall_realtime_v1.json
```

Requirements:
- Public HTTPS URL reachable by Telegram for n8n webhooks.
- Correct `N8N_WEBHOOK_URL` in `.env` (real domain, not placeholder).
- Telegram credentials assigned in `Telegram Trigger` and `Send Telegram Reply`.

Important:
- Keep only one Telegram mode active at once:
  - Realtime webhook workflow, or
  - Polling workflow.

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
| `OPNSENSE_BASE_URL` | OPNsense API base URL | `https://opnsense.local` |
| `OPNSENSE_API_KEY` | OPNsense API key for automation | empty |
| `OPNSENSE_API_SECRET` | OPNsense API secret for automation | empty |
| `OPENVPN_ENABLED` | Enable OPNsense OpenVPN-oriented lab mode | `true` |
| `WAZUH_API_USER` | Wazuh API username | `wazuh` |
| `WAZUH_API_PASSWORD` | Wazuh API password | `change-this-wazuh-password` |
| `N8N_ENCRYPTION_KEY` | n8n encryption key | `change-this-n8n-encryption-key` |
| `TELEGRAM_ALLOWED_CHAT_IDS` | Allowed Telegram chat IDs for SOAR actions | empty (allow all) |
| `FIREWALL_API_URL` | Firewall API endpoint for ChatOps commands | `http://mock-firewall:8080` |
| `FIREWALL_DASHBOARD_TOKEN` | Optional token for `/dashboard` and `/rules` endpoints | empty (disabled) |
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
1. CI validation (Python compile checks, n8n JSON validation, compose validation, smoke builds without push)
2. Security checks (Bandit, pip-audit, Trivy image scan)
3. Image release to Docker Hub from `main`/tags with signed images and SBOM artifacts
4. Controlled image promotion workflow (`dev -> staging -> prod`) using GitHub Environments

### SecDevOps Pipeline and Environments
- `ci.yml`: validation and smoke builds only (no image push).
- `security.yml`: Python/code and image security checks with severity gate policy.
- `release-images.yml`: builds/pushes `mi-soar-policy-api` and `mi-soar-edge-agent`, applies vulnerability gate before push, assigns `dev` + `sha-*` tags on default branch, generates SBOM, signs by digest (cosign keyless), and creates/verifies SBOM attestation.
- `promote-images.yml`: manual promotion by re-tagging existing published manifests (no rebuild), with `environment` gate and mandatory verify-before-promote (digest resolution, signature identity, SBOM attestation, vulnerability gate).
- `rollback-images.yml`: manual secure rollback by source tag/digest with mandatory verification before re-tagging.
- Operational runbook: [docs/pipeline-operational-validation.md](/home/s4lva/mi-soar-ngfw/docs/pipeline-operational-validation.md)
- Local smoke helper: `scripts/ci/pipeline-ops-smoke.sh`

Required repository setup for environment gates:
- Create GitHub Environments: `dev`, `staging`, `prod`.
- Configure required reviewers on `prod` environment to enforce manual approval before production promotion.

Required Docker Hub secrets:
- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`

Severity gate policy:
- Default: `CRITICAL` blocks release/promote/rollback.
- Optional stricter mode: set repository variable `SECURITY_GATE_BLOCK_HIGH=true` to block on `HIGH,CRITICAL`.

Image signing notes:
- Current workflows use keyless signing with OIDC (`cosign sign --yes`) and do not require extra signing secrets.
- If your organization requires key-based signing, add dedicated secrets (for example `COSIGN_PRIVATE_KEY` and `COSIGN_PASSWORD`) and adapt the signing step.

Signature identity policy:
- Release artifacts must verify against `.github/workflows/release-images.yml`.
- Promote/Rollback accept source signatures from release/promote/rollback workflows and re-sign target tags with their own workflow identity.
- Verification issuer is fixed to `https://token.actions.githubusercontent.com`.

Attestations:
- Build provenance is emitted by Docker Buildx (`provenance: mode=max`).
- SBOM is generated (SPDX JSON), attached as workflow artifact, and attested to the image digest with cosign keyless.

Rollback:
- Use `rollback-images.yml` (`workflow_dispatch`) with `target_environment` and either `source_tag` or `source_digest`.
- Before rollback, workflow verifies source existence, signature identity, SBOM attestation, and vulnerability gate.
- `prod` rollback remains gated by the `prod` GitHub Environment approval policy.

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

### Production (Generic VPS)
- Install Docker Engine + Docker Compose plugin
- Configure `.env` with strong credentials
- Start with `docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d`
- Verify with `./scripts/monitoring/health-checks.sh`

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
