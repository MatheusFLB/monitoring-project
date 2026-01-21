# 📡 Monitoring Stack - Grafana + Prometheus + Node Exporter

A complete server and infrastructure monitoring solution, using Node Exporter to export system data, Prometheus for metrics collection, and Grafana for visualization through pre-configured dashboards, including the Node Exporter Full dashboard (ID 1860). Includes automated deployment via Docker Compose and systemd integration to start the stack automatically on boot.

---
---

## ✨ Key Features

* Full system metrics visualization via Grafana
* CPU, memory, disk, and network monitoring with Node Exporter
* Real-time metrics collection with Prometheus
* Automatic provisioning of dashboard ID 1860 (Node Exporter Full)
* Automated deployment with systemd to start on boot
* Persistent storage for Grafana and Prometheus data

---
---

## 📦 Requirements

* Debian or Ubuntu
* sudo (for permission adjustments)
* git
* systemd
* docker
* docker-compose (v1 or v2)

---
---

## 🚀 Installation

Make sure you have the required packages:

```bash
sudo apt update && sudo apt install -y git docker.io docker-compose
```

Clone the repository:

```bash
git clone https://github.com/MatheusFLB/monitoring-project.git
cd monitoring-project
```

Make the main script executable:

```bash
chmod +x deploy.sh
```

Run the deploy script (execute as root):

```bash
sudo ./deploy.sh
```

The script will:
* Prompt a questionnaire to create the `.env` file
* Adjust permissions for persistent volumes
* Automatically provision dashboard ID 1860
* Start the Grafana, Prometheus, and Node Exporter containers
* Create and enable a systemd service to start the stack at boot

---
---

## 🧠 How it Works

* **Node Exporter** exports CPU, memory, disk, and network metrics
* **Prometheus** collects metrics from Node Exporter and stores historical data
* **Grafana** reads data from Prometheus and displays pre-configured dashboards
* **Provisioning** ensures dashboard ID 1860 is loaded automatically
* **Systemd** starts the entire stack automatically on system boot

---
---

## 🔐 Security Notes

* **Persistent volumes contain sensitive Grafana data:**

  * `grafana_data/` → users, password hashes, sessions, dashboards, and datasources
  * `grafana_provisioning/` → provisioned dashboards and datasources (less critical but reveals infrastructure structure)

* **Risk:**
  Any user or process with access to the host and the `grafana_data` directory can read sensitive Grafana data.

* **Security best practices:**

  **Secure Backup**
  Make encrypted backups of persistent volumes:

  ```bash
  tar czf grafana_backup_$(date +%F).tar.gz *_data
  ```

  **Avoid exposing volumes outside the host**

  * Do not share the folder over a public network without encryption
  * Do not grant access to untrusted host users

  **Grafana password**

  * Set a strong password in the `.env` file (`GF_SECURITY_ADMIN_PASSWORD`)
  * Never share or commit this file publicly

> ⚠️ Remember: volumes exist for **persistence and backup**, they are not security flaws by themselves. Risk only occurs if someone gains direct access to the host files.

---
---

## 🛠 Typical Use Cases

* Monitoring physical or virtual servers
* Real-time infrastructure metrics visualization
* Alerts and dashboards for DevOps or SysAdmin teams
* Base for expansion with other exporters and custom dashboards

---
---

## 👤 Author

Project created by **[Matheus Bissoli](https://www.linkedin.com/in/matheusbissoli/)** – a simple and efficient monitoring stack to keep your Linux systems fully observable.