# Official OPNsense Deployment Notes

Important: OPNsense official distribution is an appliance/ISO (FreeBSD-based), not an official Docker image.

Official download:
- https://opnsense.org/download/

Recommended lab implementation:
1. Deploy OPNsense in a VM (VirtualBox/Proxmox/ESXi/KVM).
2. Configure interfaces: WAN/LAN/MGMT (and DMZ if needed).
3. Enable OpenVPN server in OPNsense.
4. Put Suricata in IPS mode on relevant interfaces.
5. Create API key/secret for n8n automation.
6. Point n8n to OPNsense API via `OPNSENSE_BASE_URL`.

Minimal integration vars:
- OPNSENSE_BASE_URL=https://<opnsense-ip>
- OPNSENSE_API_KEY=<key>
- OPNSENSE_API_SECRET=<secret>
