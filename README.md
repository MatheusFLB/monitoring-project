# 📡 Monitoring Stack — Grafana + Prometheus + Zabbix + Loki

A comprehensive monitoring and security solution for local networks and remote hosts, built on Docker Compose with automated deployment and systemd boot integration.

| Component | Role |
|-----------|------|
| **Node Exporter** | System metrics (CPU, memory, disk, network) |
| **Prometheus** | Time-series metrics collection & storage |
| **Grafana** | Unified visualization (metrics, logs, Zabbix data) |
| **Zabbix Server** | Network & remote host monitoring (with/without agent) |
| **Zabbix Web** | Zabbix administration interface |
| **Zabbix Agent 2** | Local host active monitoring + Docker metrics |
| **Loki** | Log aggregation & indexing |
| **Promtail** | Log collection (syslog, auth, kernel, Docker containers) |

---

![](assets/panel.png)

---

## ✨ Key Features

* Full system metrics visualization via Grafana
* CPU, memory, disk, and network monitoring with Node Exporter
* Local network and remote host monitoring with Zabbix (agent & agentless)
* Centralized log aggregation with Loki + Promtail
* Security event detection (failed logins, privilege escalation, sudo commands)
* Docker container log collection and analysis
* Automatic provisioning of dashboards and multiple data sources
* Automated deployment with systemd to start on boot
* Persistent storage for all services

---

## 🏗 Architecture

```
┌──────────────────── Docker Compose (single host) ────────────────────┐
│                                                                       │
│  ┌─────────────┐   scrape   ┌─────────────────┐                      │
│  │Node Exporter├───────────►│   Prometheus     │                      │
│  └─────────────┘            └────────┬────────┘                      │
│                                      │                                │
│  ┌─────────────┐   push     ┌───────┴────────┐    ┌──────────────┐  │
│  │  Promtail   ├───────────►│     Loki       ├───►│   Grafana    │  │
│  └──────┬──────┘            └────────────────┘    │  (unified    │  │
│         │ reads                                    │   dashboard) │  │
│    /var/log/*                                      └──────┬───────┘  │
│    Docker logs                                            │          │
│                                                           │ Zabbix   │
│  ┌──────────────┐          ┌──────────────┐              │ plugin   │
│  │ Zabbix Agent ├─────────►│Zabbix Server ├──────────────┘          │
│  └──────────────┘          └──────┬───────┘                          │
│                                   │                                   │
│  ┌──────────────┐          ┌──────┴───────┐                          │
│  │  PostgreSQL  │◄─────────┤  Zabbix Web  │                          │
│  └──────────────┘          └──────────────┘                          │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘

Remote hosts (LAN):
  • With agent:    Zabbix Agent → Zabbix Server (active/passive checks)
  • Without agent: Zabbix Server → host (ICMP ping, TCP port, SNMP)
```

---

## 📦 Requirements

* Debian or Ubuntu (tested on Debian 12+)
* **6 GB RAM minimum** (8 GB+ recommended)
* sudo privileges
* git, docker, docker-compose (v1 or v2)
* openssl (for automatic password generation)

---

## 🚀 Installation

Install required packages:

```bash
sudo apt update && sudo apt install -y git docker.io docker-compose openssl
```

Clone the repository:

```bash
git clone https://github.com/MatheusFLB/monitoring-project.git
cd monitoring-project
```

Make the deploy script executable:

```bash
chmod +x deploy.sh
```

Run the deploy script (as root):

```bash
sudo ./deploy.sh
```

The script will:
* Check available system resources
* Prompt for passwords, ports, and timezone
* Auto-generate the Zabbix database password
* Create persistent data directories with correct permissions
* Start all containers
* Create and enable a systemd service for boot startup

---

## 🌐 Access Points

| Service | Default URL | Default Credentials |
|---------|-------------|-------------------|
| **Grafana** | `http://localhost:3000` | admin / *(set during deploy)* |
| **Prometheus** | `http://localhost:9090` | — |
| **Zabbix Web** | `http://localhost:8080` | Admin / zabbix |
| **Loki API** | `http://localhost:3100` | — |

> ⚠️ Change the default Zabbix password immediately after first login.

---

## 🧠 How it Works

### Metrics (Prometheus + Node Exporter)
* **Node Exporter** exports CPU, memory, disk, and network metrics from the central host
* **Prometheus** scrapes metrics every 15 seconds and stores them with 30-day retention
* Visualized in Grafana via the pre-provisioned Prometheus data source

### Network & Host Monitoring (Zabbix)
* **Zabbix Server** manages monitoring of local and remote hosts
* **Zabbix Agent 2** runs on the central host for detailed local metrics + Docker monitoring
* Remote hosts can be monitored in two modes:
  * **With agent** — Install Zabbix Agent on remote hosts pointing to the server IP
  * **Without agent** — Configure ICMP ping, TCP port checks, or SNMP in Zabbix Web
* Zabbix data is visualized in Grafana via the Zabbix plugin or in the native Zabbix Web interface

### Logs & Security Events (Loki + Promtail)
* **Promtail** collects logs from:
  * `/var/log/syslog` — system events
  * `/var/log/auth.log` — authentication events
  * `/var/log/kern.log` — kernel messages
  * Docker container logs via Docker socket
* **Loki** indexes and stores logs with 30-day retention
* Security-relevant events are labeled automatically:
  * Failed/successful passwords, sudo commands, invalid users, session events
* Logs are queryable in Grafana via the Loki data source using LogQL

---

## 📡 Adding Remote Hosts

### With Zabbix Agent (recommended for managed hosts)

Install Zabbix Agent on the remote host:

```bash
# Debian/Ubuntu
wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu24.04_all.deb
sudo dpkg -i zabbix-release_latest_7.0+ubuntu24.04_all.deb
sudo apt update && sudo apt install -y zabbix-agent2
```

Configure the agent (`/etc/zabbix/zabbix_agent2.conf`):

```ini
Server=<MONITORING_HOST_IP>
ServerActive=<MONITORING_HOST_IP>
Hostname=<UNIQUE_HOST_NAME>
```

Restart the agent:

```bash
sudo systemctl restart zabbix-agent2
sudo systemctl enable zabbix-agent2
```

Then add the host in **Zabbix Web → Data collection → Hosts → Create host**.

### Without Agent (ICMP/TCP/SNMP)

In **Zabbix Web → Data collection → Hosts → Create host**:
1. Set the host IP address
2. Link the template **ICMP Ping** (or **Generic SNMP** for SNMP devices)
3. Zabbix Server will run the checks directly — no agent needed on the remote host

---

## 🔐 Security Notes

* **Credentials:**
  * `.env` contains all passwords — protected with mode `600` and excluded from git
  * Zabbix DB password is auto-generated with `openssl rand`
  * Change the default Zabbix Web password (`Admin / zabbix`) after first login

* **Persistent volumes contain sensitive data:**
  * `grafana_data/` — users, password hashes, sessions
  * `zabbix_db_data/` — full Zabbix database including host inventory
  * `loki_data/` — aggregated logs (may contain sensitive system events)

* **Exposed ports:**
  * All services bind to `0.0.0.0` by default — restrict with a firewall if public-facing
  * Zabbix Server port `10051` must be reachable by remote agents

* **Best practices:**
  * Use a firewall (`ufw`, `iptables`) to restrict access to trusted IPs
  * Back up persistent volumes regularly with encrypted archives
  * Consider a reverse proxy (Nginx) with TLS for production environments
  * Do not expose the Docker socket to untrusted containers

---

## 📁 Project Structure

```
monitoring-project/
├── docker-compose.yml          # All services orchestration
├── deploy.sh                   # Automated deployment script
├── .env.example                # Environment variable template
├── .gitignore                  # Excludes .env and data directories
├── README.md                   # This file
│
├── prometheus/
│   └── prometheus.yml          # Scrape configuration
├── prometheus_data/            # Prometheus TSDB (persistent)
│
├── grafana_provisioning/
│   ├── datasources/
│   │   └── datasource.yml      # Prometheus + Loki + Zabbix sources
│   └── dashboards/
│       ├── dashboard.yml        # Dashboard provider config
│       └── 1860_rev27.json      # Node Exporter Full dashboard
├── grafana_data/               # Grafana state (persistent)
│
├── loki/
│   └── loki.yml                # Loki server configuration
├── loki_data/                  # Loki chunks & index (persistent)
│
├── promtail/
│   └── promtail.yml            # Log collection configuration
│
├── zabbix_db_data/             # PostgreSQL data (persistent)
├── zabbix_server_data/         # Zabbix Server state (persistent)
│
├── systemd/
│   └── monitoring-app.service.template  # Systemd unit template
└── assets/
    └── panel.png               # Screenshot
```

---

## 🛠 Typical Use Cases

* Monitoring physical or virtual servers in a local network
* Network availability monitoring (ICMP, TCP, SNMP) via Zabbix
* Real-time infrastructure metrics visualization
* Centralized security log analysis (failed logins, intrusions, sudo activity)
* Docker container health and log monitoring
* Alerts and dashboards for DevOps or SysAdmin teams
* Base for expansion with additional exporters and Zabbix templates

---

## ⚠️ Resource Considerations

This stack runs 8 containers. On constrained hardware (dual-core, 6 GB RAM):
* Expect ~3–4 GB RAM usage at idle
* Zabbix DB cache is set conservatively (`ZBX_CACHESIZE=32M`)
* Prometheus retention is 30 days — monitor disk usage
* Loki retention is 30 days with automatic compaction
* If resources are insufficient, stop the least critical service temporarily:
  ```bash
  docker compose stop loki promtail   # Pause log collection
  docker compose stop zabbix-web      # Pause Zabbix UI (server keeps collecting)
  ```

---

## 👤 Author

Project created by **[Matheus Bissoli](https://www.linkedin.com/in/matheusbissoli/)** — a comprehensive monitoring and security stack for Linux infrastructure.