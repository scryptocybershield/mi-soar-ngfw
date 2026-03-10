# MI-SOAR-NGFW Architecture

## Overview

MI-SOAR-NGFW is a multi-container security platform that integrates Next-Generation Firewall (NGFW) capabilities with Security Orchestration, Automation, and Response (SOAR) functionality. The architecture is designed for hybrid deployment across local, cloud, and edge environments.

## Architectural Principles

1. **Container Isolation**: Each security service runs in its own container with minimal required privileges
2. **Defense in Depth**: Multiple layers of security controls with coordinated response
3. **Automation First**: Security operations automated through workflows where possible
4. **Cloud-Native Design**: Stateless where possible, persistent storage for configurations and logs
5. **Hybrid Deployment**: Consistent architecture across local, cloud, and edge deployments

## Component Architecture

### 1. Network Security Layer

```
┌─────────────────────────────────────────────────────────────┐
│                    Network Security Layer                    │
├──────────────┬────────────────┬─────────────────────────────┤
│   Suricata   │   nftables     │        WireGuard            │
│   (IDS/IPS)  │   (Firewall)   │         (VPN)               │
└──────────────┴────────────────┴─────────────────────────────┘
```

#### Suricata (Intrusion Detection/Prevention System)
- **Role**: Deep packet inspection and threat detection
- **Mode**: Network-based IDS/IPS with nftables integration
- **Capabilities**: NET_RAW, host network access
- **Integration**: NFQUEUE with nftables for inline prevention
- **Outputs**: JSON alerts to Wazuh, local logging

#### nftables (Firewall)
- **Role**: Stateful packet filtering and traffic shaping
- **Integration**: Dynamic rule updates from Suricata and n8n
- **Features**: Connection tracking, NAT, port forwarding
- **Management**: Rules versioning and rollback capability

#### WireGuard (VPN)
- **Role**: Secure remote access and site-to-site connectivity
- **Capabilities**: NET_ADMIN, kernel module access
- **Features**: Automated peer provisioning, roaming support
- **Integration**: n8n workflows for access management

### 2. Security Operations Layer

```
┌─────────────────────────────────────────────────────────────┐
│                 Security Operations Layer                    │
├──────────────┬────────────────┬─────────────────────────────┤
│    Wazuh     │      n8n       │        Traefik              │
│    (SIEM)    │    (SOAR)      │    (Reverse Proxy)          │
└──────────────┴────────────────┴─────────────────────────────┘
```

#### Wazuh (Security Information and Event Management)
- **Role**: Log aggregation, correlation, and alerting
- **Components**: Manager, Indexer, Dashboard (single-node)
- **Integration**: Suricata alerts, system logs, custom applications
- **Active Response**: Automated actions based on alerts

#### n8n (Security Orchestration, Automation, and Response)
- **Role**: Workflow automation for security operations
- **Custom Nodes**: Suricata, Wazuh, nftables, WireGuard integrations
- **Workflows**: Incident response, access provisioning, threat hunting
- **Triggers**: Webhooks, schedules, API calls, alert events

#### Traefik (Reverse Proxy)
- **Role**: Service discovery, load balancing, SSL termination
- **Features**: Automatic SSL with Let's Encrypt, service discovery
- **Security**: HTTP/2, CORS, rate limiting, basic auth
- **Monitoring**: Metrics, access logs, health checks

## Data Flow

### 1. Threat Detection Flow
```
Network Traffic → Suricata (Detection) → Alert Generation → Wazuh (Correlation) → n8n (Automation) → nftables (Blocking)
```

### 2. VPN Access Flow
```
VPN Client → WireGuard (Authentication) → nftables (Filtering) → Internal Services → Logging (Wazuh)
```

### 3. Incident Response Flow
```
Alert (Wazuh) → Webhook (n8n) → Workflow Execution → Actions (Block IP, Notify, Quarantine) → Verification (Health Check)
```

## Network Architecture

### Docker Networks
```
┌─────────────────────────────────────────────────────────────┐
│                    Docker Host Network                       │
│  (Required for Suricata, WireGuard, nftables)               │
└─────────────────────────────────────────────────────────────┘
                            │
┌─────────────────────────────────────────────────────────────┐
│                    mi-soar-network                          │
│          (Internal service communication)                   │
├──────────────┬────────────────┬─────────────────────────────┤
│   Wazuh      │      n8n       │        Traefik              │
│  10.10.0.10  │   10.10.0.20   │       10.10.0.30            │
└──────────────┴────────────────┴─────────────────────────────┘
```

### Network Segmentation
1. **Host Network**: Suricata, WireGuard, nftables (requires direct network access)
2. **Internal Network**: Wazuh, n8n, Traefik (isolated service communication)
3. **Management Network**: Optional separate network for administration

## Storage Architecture

### Persistent Volumes
```
storage/
├── logs/                    # Centralized log storage
│   ├── suricata/           # Suricata alert and event logs
│   ├── wazuh/              # Wazuh agent and manager logs
│   ├── n8n/                # n8n execution logs
│   └── traefik/            # Access and error logs
├── wazuh-data/             # Wazuh database and indices
├── n8n-data/               # n8n workflows and credentials
└── rules/                  # Suricata rule updates
```

### Configuration Management
```
configs/
├── suricata/               # Suricata configuration
├── wireguard/              # WireGuard server config
├── nftables/               # nftables rule sets
├── wazuh/                  # Wazuh manager config
├── n8n/                    # n8n configuration
└── traefik/                # Traefik dynamic config
```

## Security Architecture

### Container Security
- **Non-root Users**: All containers run as non-root users
- **Capability Management**: Minimal Linux capabilities (NET_ADMIN, NET_RAW only where needed)
- **Read-only Filesystems**: Configuration volumes mounted read-only
- **Resource Limits**: CPU, memory, and process limits per container
- **Seccomp Profiles**: Default Docker seccomp profiles with customizations

### Network Security
- **Service Isolation**: Internal network for service communication
- **Encryption**: TLS for internal API communication
- **Firewall Rules**: Default deny, explicit allow rules
- **VPN Encryption**: WireGuard with perfect forward secrecy

### API Security
- **Authentication**: API keys, JWT tokens, or mutual TLS
- **Authorization**: Role-based access control
- **Rate Limiting**: Request throttling per service
- **Audit Logging**: All API calls logged and monitored

## Deployment Architectures

### 1. Local Development (VirtualBox)
- Single host with all containers
- Host volume mounts for easy development
- Reduced resource requirements
- Development-specific configurations

### 2. Cloud Run (Serverless)
- Containerized deployment on GCP Cloud Run
- Automatic scaling based on load
- Cloud Storage for configurations
- Managed SSL and load balancing

### 3. Compute Engine (Virtual Machine)
- Dedicated VM with persistent storage
- Systemd service management
- GCP Cloud Monitoring integration
- Backup and snapshot capabilities

### 4. High Availability (Future)
- Multiple availability zones
- Load balancer with health checks
- Database replication
- Automated failover procedures

## Scalability Considerations

### Vertical Scaling
- Increase container resource limits
- Optimize rule sets and configurations
- Tune detection engine parameters

### Horizontal Scaling
- Suricata workers per CPU core
- Multiple n8n workers for parallel workflows
- Wazuh cluster for larger deployments
- Load-balanced Traefik instances

### Performance Optimization
- Rule optimization for Suricata
- Connection pooling for databases
- Caching for frequently accessed data
- Asynchronous processing where possible

## Monitoring Architecture

### Health Checks
- Container-level health checks (Docker HEALTHCHECK)
- Service-level health checks (HTTP endpoints)
- Platform-level health checks (comprehensive validation)
- External monitoring (uptime checks)

### Metrics Collection
- Container metrics (CPU, memory, network)
- Application metrics (requests, errors, latency)
- Security metrics (alerts, blocks, false positives)
- Business metrics (incident response time, MTTD, MTTR)

### Alerting
- Wazuh alert correlation
- n8n workflow triggers
- External notification (Email, Slack, PagerDuty)
- Escalation policies

## Disaster Recovery

### Backup Strategy
- Configuration backups (version-controlled)
- Database backups (automated snapshots)
- Log archives (compressed and rotated)
- Rule set backups (versioned)

### Recovery Procedures
- Container restart with health checks
- Configuration rollback
- Database restoration
- Full platform restoration

### Testing
- Regular backup restoration tests
- Disaster recovery drills
- Failover testing
- Performance under failure conditions

## Future Architecture Enhancements

### Planned Features
1. **Multi-tenancy**: Separate workspaces for different teams
2. **Machine Learning**: Anomaly detection with ML models
3. **Threat Intelligence**: Integration with external TI feeds
4. **Compliance Reporting**: Automated compliance reports
5. **Mobile App**: Management and monitoring mobile application

### Integration Points
1. **Ticketing Systems**: Jira, ServiceNow, Zendesk
2. **Communication Tools**: Slack, Microsoft Teams, Discord
3. **Cloud Platforms**: AWS, Azure, OVH, DigitalOcean
4. **Security Tools**: VirusTotal, Shodan, AbuseIPDB

## Technical Specifications

### Minimum Requirements
- **CPU**: 4 cores
- **RAM**: 8GB
- **Storage**: 50GB SSD
- **Network**: 1Gbps
- **OS**: Linux with Docker support

### Recommended Production
- **CPU**: 8+ cores
- **RAM**: 16GB+
- **Storage**: 200GB+ SSD with backups
- **Network**: 10Gbps with DDoS protection
- **OS**: Debian 11/12, Ubuntu 20.04/22.04 LTS

### Container Images
- **Base**: Debian bookworm-slim
- **Suricata**: jasonish/suricata:latest
- **WireGuard**: linuxserver/wireguard:latest
- **Wazuh**: wazuh/wazuh:4.7.x
- **n8n**: n8nio/n8n:latest
- **Traefik**: traefik:v3.0

## Compliance Considerations

### Regulatory Frameworks
- **GDPR**: Data protection and privacy
- **PCI DSS**: Payment card security
- **HIPAA**: Healthcare information security
- **ISO 27001**: Information security management
- **NIST CSF**: Cybersecurity framework

### Security Controls
- Access control and authentication
- Audit logging and monitoring
- Encryption in transit and at rest
- Vulnerability management
- Incident response procedures