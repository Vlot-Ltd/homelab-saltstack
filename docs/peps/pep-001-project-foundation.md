# PEP-001: Project Foundation

**PEP:** 001  
**Title:** Project Foundation  
**Author:** Timo Vlot  
**Status:** Active  
**Type:** Project  
**Created:** 2026-05-12  
**Updated:** 2026-05-12  
**Supersedes:** N/A  
**Superseded-By:** N/A  

## Abstract

This document describes the current state of the homelab SaltStack infrastructure — the technology stack, managed hosts, deployed services, network topology, and development standards. It serves as the reference point for all subsequent PEPs.

## Motivation

A foundation document provides new PEPs with a shared baseline: what exists, how it is organised, and what conventions apply. It also captures decisions that are obvious to the author now but would require archaeology to recover later.

## Current Infrastructure

### Salt Architecture

- **Salt Master**: Central controller, manages all minions via ZeroMQ
- **Minions**: Each host runs `salt-minion`, assigned states via `salt/top.sls` and pillar via `pillar/top.sls`
- **Mine**: Used for inter-minion data sharing (IP addresses, hostnames) — configured via `salt/common/mine_functions.sls`
- **Scheduler**: All minions run highstate every 30 minutes with a 10-second splay (`pillar/common/schedule.sls`)

### Managed Hosts (Minion Roles)

| Role/Grain | Purpose | OS |
|---|---|---|
| `docker` | Primary Docker host running containerised services | Ubuntu 24.04 |
| `postgres` | Dedicated PostgreSQL server | Ubuntu 24.04 |
| `plex` | Plex Media Server | Ubuntu 24.04 |
| `netbox` | NetBox IPAM/DCIM | Ubuntu 24.04 |
| `zabbix` | Zabbix monitoring server + Grafana | Ubuntu 24.04 |
| `vault` | HashiCorp Vault secrets management | Ubuntu 24.04 |
| `nlremote` | Remote host (Netherlands) | Ubuntu 24.04 |
| `pi` (KVM grain) | Raspberry Pi hardware monitoring | Raspberry Pi OS |
| Mac | Development/desktop machine | macOS (arm64) |

All Linux hosts receive: common state, OS patches, QEMU agent (if VM), Zabbix agent, Docker client, Tailscale.

### Network

- **LAN**: `192.168.0.0/24` — static host entries managed via `pillar/common/hosts.sls`
- **Tailscale**: All hosts connected to tailnet `taile3eee.ts.net` — primary connectivity method for cross-host communication and remote access
- **Tailscale IPs**: `100.x.x.x` range — Docker host at `100.73.13.74`

### Services and Where They Run

**Docker host (containerised):**
- Heimdall2 — application dashboard
- Homepage — start page with service widgets
- Linkwarden — bookmark manager
- Alertmanager — alert routing
- Fing Agent — network device discovery
- Tailscale (sidecar) — container network access via Tailscale
- Webdriver (Selenium Chrome) — browser automation for monitoring scripts

**Dedicated hosts:**
- PostgreSQL — shared database server for Zabbix, NetBox, Linkwarden, Heimdall2
- Plex Media Server — media streaming
- NetBox 4.3.1 — IPAM and infrastructure documentation
- Zabbix 7.2 — monitoring, alerting, and metrics collection
- Grafana — dashboards backed by Zabbix datasource
- HashiCorp Vault — secrets management (KV v2 engine)

### Monitoring

- **Zabbix server**: `zabbix.taile3eee.ts.net`
- **Grafana**: `http://100.107.102.4:3000`
- **Zabbix agent 2**: installed on all Linux hosts, configured per host via template
- **Custom monitoring**: Plex monitoring scripts via `uv`/Python in `/opt/plex-monitoring`
- **Security scanning**: InSpec, Lynis, rkhunter — results uploaded to Heimdall2

### Security

- All hosts run periodic security scans (InSpec CIS/linux-baseline/ssh-baseline, Lynis, rkhunter, chkrootkit, AIDE, ClamAV)
- Scan results uploaded to Heimdall2 results server
- Tailscale provides network-layer encryption between hosts
- Vault provides secrets management (currently with TLS disabled — see PEP-004)

## Technology Stack

| Layer | Technology |
|---|---|
| Config management | SaltStack (latest stable) |
| Secrets | HashiCorp Vault (KV v2), file backend |
| Containers | Docker + Compose |
| Networking | Tailscale + LAN (192.168.0.0/24) |
| Database | PostgreSQL (shared) |
| Monitoring | Zabbix 7.2 + Grafana |
| OS | Ubuntu 24.04 (servers), Raspberry Pi OS, macOS arm64 |
| Virtualisation | Proxmox/KVM |
| Templating | Jinja2 (within SaltStack) |

## Repository Structure

```
homelab-saltstack/
├── pillar/                  # Pillar data (config and secrets per minion)
│   ├── top.sls              # Pillar → minion assignments
│   ├── common/              # Applied to all minions
│   └── application/         # Per-service pillar data
├── salt/                    # State files (what to install and configure)
│   ├── top.sls              # State → minion assignments
│   ├── common/              # Applied to all Linux hosts
│   ├── os/                  # OS-specific states (linux, mac)
│   ├── hardware/            # Hardware-specific states (Pi)
│   ├── database/            # PostgreSQL states
│   └── application/         # Per-service states
├── conf/                    # Salt minion configuration fragments
├── docs/
│   ├── peps/                # Project Enhancement Packages
│   ├── blogs/               # Build logs (implementation records)
│   └── templates/           # PEP and BLOG templates
└── tools/
    └── pep-tools.sh         # PEP management CLI
```

## Development Standards

### Branching and Commits

- Branch naming: `feature/pep-XXX-description`, `fix/pep-XXX-issue`, `docs/pep-XXX-update`
- Commit format: `pep-XXX: description` or `chore: maintenance tasks`
- All significant changes require a PEP before implementation

### Salt Conventions

- Pillar data is the single source of truth for configuration values
- Secrets must come from Vault, not hardcoded pillar values (target state — see PEP-002)
- States must be idempotent — running highstate twice produces no changes
- Service restarts triggered via `watch`/`watch_in` on config file changes
- All Linux hosts receive the `common` state; role-specific states assigned by grain

### PEP Workflow

1. Create a PEP describing the intended change
2. Implement on a feature branch, referencing the PEP number in commits
3. Write a BLOG documenting what was actually built
4. Merge to `main`

## Known Issues and Active PEPs

| PEP | Title | Status |
|-----|-------|--------|
| PEP-002 | Migrate Hardcoded Secrets to Vault | Draft |
| PEP-003 | Fix SQL Injection in PostgreSQL States | Draft |
| PEP-004 | Enable TLS on HashiCorp Vault | Draft |
| PEP-005 | Fix Structural State Flaws | Draft |
| PEP-006 | Salt State Quality Improvements | Draft |
| PEP-007 | Codebase Cleanup | Draft |
| PEP-008 | Restore Vault Pillar Integration | Draft |

## References

- `salt/top.sls` — state-to-minion assignments
- `pillar/top.sls` — pillar-to-minion assignments
- `docs/peps/` — all enhancement proposals
- SaltStack documentation: https://docs.saltproject.io
- HashiCorp Vault documentation: https://developer.hashicorp.com/vault

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 0.1 | 2026-05-12 | Timo Vlot | Initial foundation document |
