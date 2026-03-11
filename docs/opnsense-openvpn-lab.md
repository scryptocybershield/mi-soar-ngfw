# OPNsense + OpenVPN Lab Blueprint

## Objective
Route endpoint traffic through a real firewall path (VPN -> OPNsense -> IDS/IPS) while keeping SOAR orchestration in n8n.

## Target Topology

```
Endpoints (Linux/Windows/macOS)
   -> OpenVPN tunnel
   -> OPNsense (WAN/LAN/MGMT)
   -> Suricata inline (IPS) on OPNsense
   -> Internal services (Wazuh, n8n, apps)
   -> SOAR actions back to OPNsense API
```

## Segmentation
- `MGMT`: admin access (OPNsense GUI/API, n8n, Wazuh dashboard)
- `LAN`: trusted internal workloads
- `DMZ`: exposed services
- Default policy: deny by default between segments, explicit allow-list only.

## Recommended Implementation Order

1. Deploy OPNsense as primary gateway.
2. Create VLANs/interfaces: `LAN`, `DMZ`, `MGMT`.
3. Enable Suricata on OPNsense in IPS mode for relevant interfaces.
4. Configure OpenVPN Remote Access Server on OPNsense.
5. Force endpoint routes through VPN:
   - push `redirect-gateway def1`
   - push internal DNS
   - split tunnel only if required.
6. Expose OPNsense API key/secret for automation.
7. In n8n, use OPNsense API adapter workflows for:
   - add/remove block aliases
   - apply/reload firewall rules
   - query current policy state.
8. Keep `mock-firewall` as fallback profile for local/CI tests.

## SOAR Integration Pattern

- Detection:
  - Wazuh alerts + Suricata events.
- Enrichment:
  - TI lookup (IP reputation, geolocation, ASN).
- Decision:
  - Severity and confidence thresholds.
  - `HIGH/CRITICAL`: approval in Telegram.
- Response:
  - Update OPNsense alias/rule.
  - Optional host isolation task.
- Audit:
  - Write action event to Wazuh index + n8n execution logs.

## OpenVPN Baseline (Server-side Policy)
- TLS auth required.
- Client cert per endpoint.
- MFA for admin users (if available).
- Per-group ACL:
  - `SOC_ADMIN` full MGMT access
  - `ENDPOINT_USER` limited LAN access
- Revocation workflow:
  - certificate revoke + CRL update + active session kill.

## Validation Checklist
- Endpoint without VPN: blocked from internal apps.
- Endpoint with VPN: only allowed segment access works.
- IDS alert triggers in Wazuh and is visible in dashboard.
- Telegram command -> n8n -> OPNsense API -> rule applied.
- Block is verifiable from endpoint traffic tests.

## Rollout Strategy
- Phase A: parallel deployment (keep current docker path).
- Phase B: move one endpoint group to OpenVPN.
- Phase C: switch default lab path to OPNsense/OpenVPN.
- Phase D: keep mock path only for CI smoke tests.
