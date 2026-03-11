# OPNsense Official Migration Runbook (from current Docker lab)

## Scope
Migrate the lab from Docker-centric VPN/firewall path to an official OPNsense VM path, preserving:
- Wazuh detection/correlation
- n8n SOAR workflows (Telegram ChatOps)
- Mock firewall fallback for CI/local smoke tests

Date baseline: 2026-03-11

---

## 1. Target Network Design

Use these subnets to stay aligned with current repo defaults:
- `MGMT`: `10.10.0.0/24` (existing services: n8n/Wazuh/mock)
- `LAN`: `10.10.10.0/24` (internal endpoints)
- `DMZ`: `10.10.20.0/24` (exposed services if needed)
- `OpenVPN TUN`: `10.8.0.0/24`

Recommended OPNsense interfaces:
- `WAN`: upstream/corporate or NAT egress
- `LAN`: 10.10.10.1/24
- `DMZ`: 10.10.20.1/24
- `MGMT`: 10.10.0.1/24

Policy baseline:
- Deny by default inter-segment.
- Explicit allow rules only.
- Allow MGMT -> OPNsense GUI/API.

---

## 2. Deploy Official OPNsense VM

1. Download official image from:
- https://opnsense.org/download/

2. VM sizing (lab minimum):
- 4 vCPU
- 8 GB RAM
- 40 GB disk
- 3-4 NICs (WAN, MGMT, LAN, optional DMZ)

3. Initial hardening after first boot:
- Change `root` password
- Disable GUI admin from WAN
- Enable MFA for admin if possible
- Restrict SSH to MGMT subnet only

4. Access dashboard:
- `https://<OPNSENSE_MGMT_IP>/`

---

## 3. OpenVPN Remote Access (on OPNsense)

1. Create internal CA + server certificate.
2. Create users/certs per endpoint.
3. Configure OpenVPN server:
- Tunnel network: `10.8.0.0/24`
- Push routes: `10.10.10.0/24`, `10.10.20.0/24`, `10.10.0.0/24` (as needed)
- For full-tunnel tests: push `redirect-gateway def1`
- Push DNS (OPNsense or internal resolver)

4. Firewall rules:
- WAN: allow OpenVPN port (UDP/TCP chosen profile)
- OpenVPN tab: allow only required destination networks/services

5. Validate:
- VPN client obtains `10.8.0.x`
- Client reaches allowed services only
- Disallowed paths are blocked

---

## 4. Suricata IPS on OPNsense

1. Enable Suricata on `LAN`, `DMZ`, and optionally `OpenVPN`.
2. Start with IDS mode, then switch to IPS (inline/block) after tuning.
3. Enable relevant rulesets (ET Open, policy sets).
4. Suppress noisy signatures before enabling drop.
5. Send Suricata events/logs to Wazuh path (syslog or file forwarder).

Validation:
- Trigger controlled test signatures.
- Confirm event in OPNsense + Wazuh.
- Confirm block action when in IPS mode.

---

## 5. n8n <-> OPNsense API Integration

1. In OPNsense:
- Create API key/secret for automation user (least privilege).

2. In `.env`:
```bash
OPNSENSE_BASE_URL=https://<OPNSENSE_MGMT_IP>
OPNSENSE_API_KEY=<key>
OPNSENSE_API_SECRET=<secret>
OPENVPN_ENABLED=true
OPENVPN_TUNNEL_CIDR=10.8.0.0/24
```

3. In n8n:
- Add credential for OPNsense API.
- Build/activate workflows:
  - Add/remove firewall alias entries
  - Apply/reload filter
  - Query block status

4. Keep `FIREWALL_API_URL` pointing to `mock-firewall` during migration tests.
5. Cutover by switching actions to OPNsense workflow branch.

---

## 6. SOAR Action Policy

Recommended gating:
- `LOW/MEDIUM`: notify + enrich only.
- `HIGH`: suggest action, require Telegram approval.
- `CRITICAL`: auto-block temporary (e.g., 30 min) + immediate analyst notification.

Mandatory safeguards:
- Protected allowlist (infra IPs, management ranges).
- Max TTL cap for automatic blocks.
- Full action audit trail (who/when/why/result).

---

## 7. Cutover Plan (No-Downtime Lab)

Phase A (parallel):
- OPNsense VM online, OpenVPN clients connected, Suricata in IDS mode.

Phase B (pilot):
- Move 1-2 test endpoints behind OpenVPN.
- Keep current docker path active.

Phase C (enforcement):
- Enable IPS drop for tuned rules.
- Move Telegram block/unblock to OPNsense API actions.

Phase D (stabilize):
- Keep mock-firewall only for CI and offline testing.

Rollback:
- n8n switch back to mock action branch.
- Disable IPS drop (return to IDS).
- Keep VPN route but bypass block automation.

---

## 8. Day-1 Checklist

1. OPNsense VM running, GUI reachable on MGMT.
2. OpenVPN server up, one client connected.
3. Suricata generating alerts (IDS mode first).
4. Wazuh receives OPNsense/Suricata telemetry.
5. n8n can call OPNsense API with test request.
6. Telegram command test:
- `/status` returns OPNsense-related status branch.
- `/block <test-ip> 10` applies temp rule/alias.

