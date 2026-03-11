# SOAR Lab Roadmap (Incremental)

## Goal
Build an end-to-end cyber lab with IDS/IPS detection, automated response, and ChatOps control from Telegram via n8n.

## Phase 1 (Implemented now)
- Detection and triage:
  - Wazuh alert ingestion to n8n
  - Telegram alert notifications
- ChatOps response:
  - `/block`, `/unblock`, `/list`, `/status`, `/help`
  - Enforcement against `mock-firewall` API
- Local-first operation:
  - No public Telegram webhook required (polling workflow)

## Phase 2 (Next)
- Replace mock enforcement with real enforcement path:
  - Primary: OPNsense API (aliases/rules apply)
  - VPN path: OpenVPN remote access through OPNsense
- Add action audit trail:
  - Write response actions back to Wazuh as custom events
- Add safety controls:
  - allowlist for protected IP ranges
  - max TTL and approval gates for high-impact actions

## Phase 3
- L7-oriented controls and policy orchestration:
  - OPNsense plugin/API policy updates
  - Suricata + Wazuh correlation-driven policy templates
- CI/CD:
  - GitHub Actions smoke tests with mock data
  - VPS deployment pipeline with health checks and rollback

## OPNsense/OpenVPN decision
- Current direction: OPNsense + OpenVPN as default lab traffic path.
- Keep n8n as single orchestration layer.
- Keep `mock-firewall` only for local smoke tests and CI fallback.
