#!/usr/bin/env bash
set -e

SERVICE_NAME="monitoring-app.service"
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}"
TEMPLATE_PATH="./systemd/monitoring-app.service.template"
ENV_EXAMPLE=".env.example"
ENV_FILE=".env"

echo "🚀 Starting Monitoring Stack deploy"
echo "-------------------------------------"

# ===============================
# 1. Check dependencies
# ===============================
command -v docker >/dev/null 2>&1 || {
  echo "❌ Docker is not installed"
  exit 1
}

if command -v docker-compose >/dev/null 2>&1; then
  DOCKER_COMPOSE="$(which docker-compose)"
elif docker compose version >/dev/null 2>&1; then
  DOCKER_COMPOSE="docker compose"
else
  echo "❌ Docker Compose not found"
  exit 1
fi

# ===============================
# 1.5 Resource pre-check
# ===============================
TOTAL_RAM_MB=$(awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo)
if [[ "$TOTAL_RAM_MB" -lt 4096 ]]; then
  echo "⚠️  Warning: this host has only ${TOTAL_RAM_MB} MB RAM."
  echo "   The full stack works best with ≥ 6 GB. Expect higher swap usage."
fi

# ===============================
# 2. .env configuration
# ===============================
if [[ -f "$ENV_FILE" ]]; then
  echo "⚠️ .env file already exists."
  read -p "Do you want to reuse it? (y/n): " reuse_env
  if [[ "$reuse_env" != "y" ]]; then
    rm -f "$ENV_FILE"
  fi
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "📝 Creating .env file"
  echo "-------------------------------------"

  # ── Grafana / Prometheus / Node Exporter ──
  read -s -p "Grafana admin password: " GF_SECURITY_ADMIN_PASSWORD
  echo
  read -p "Grafana port (e.g., 3000): " GRAFANA_PORT
  read -p "Prometheus port (e.g., 9090): " PROMETHEUS_PORT
  read -p "Node Exporter port (e.g., 9100): " NODE_EXPORTER_PORT

  # ── Zabbix ──
  echo "-------------------------------------"
  echo "📝 Zabbix configuration"
  ZABBIX_DB_PASSWORD=$(openssl rand -base64 18 2>/dev/null || head -c 18 /dev/urandom | base64)
  echo "   (Zabbix DB password generated automatically)"
  read -p "Zabbix Web port (e.g., 8080): " ZABBIX_WEB_PORT
  read -p "Zabbix Server port (e.g., 10051): " ZABBIX_SERVER_PORT
  read -p "Zabbix agent hostname for this host (e.g., monitoring-host): " ZABBIX_AGENT_HOSTNAME
  read -p "Timezone (e.g., America/Sao_Paulo): " TZ

  # ── Loki ──
  echo "-------------------------------------"
  echo "📝 Loki configuration"
  read -p "Loki port (e.g., 3100): " LOKI_PORT

  cat <<EOF > "$ENV_FILE"
# ── Grafana / Prometheus / Node Exporter ──
GF_SECURITY_ADMIN_PASSWORD=$GF_SECURITY_ADMIN_PASSWORD
GRAFANA_PORT=$GRAFANA_PORT
PROMETHEUS_PORT=$PROMETHEUS_PORT
NODE_EXPORTER_PORT=$NODE_EXPORTER_PORT

# ── Zabbix ──
ZABBIX_DB_NAME=zabbix
ZABBIX_DB_USER=zabbix
ZABBIX_DB_PASSWORD=$ZABBIX_DB_PASSWORD
ZABBIX_SERVER_PORT=$ZABBIX_SERVER_PORT
ZABBIX_WEB_PORT=$ZABBIX_WEB_PORT
ZABBIX_AGENT_HOSTNAME=${ZABBIX_AGENT_HOSTNAME:-monitoring-host}
ZBX_CACHESIZE=32M
ZBX_STARTPOLLERS=3
ZBX_STARTPINGERS=2
TZ=${TZ:-America/Sao_Paulo}

# ── Loki ──
LOKI_PORT=$LOKI_PORT
EOF

  chmod 600 "$ENV_FILE"
  echo "✅ .env file created successfully"
fi

# ===============================
# 3. Project directory
# ===============================
WORKING_DIR="$(pwd)"

echo "📁 Project: $WORKING_DIR"
echo "🐳 Docker Compose: $DOCKER_COMPOSE"

# ===============================
# 4. Create persistent directories
# ===============================
echo "📂 Ensuring persistent directories exist..."
mkdir -p grafana_data grafana_provisioning \
         prometheus_data \
         zabbix_db_data zabbix_server_data \
         loki_data loki promtail

# ===============================
# 5. Adjust permissions
# ===============================
echo "🔐 Adjusting volume permissions..."

# Grafana (UID 472)
sudo chown -R 472:472 grafana_data grafana_provisioning
sudo chmod -R 700 grafana_data grafana_provisioning

# Prometheus (UID 65534 — nobody)
sudo chown -R 65534:65534 prometheus_data
sudo chmod -R 700 prometheus_data

# Loki (UID 10001 — loki default)
sudo chown -R 10001:10001 loki_data
sudo chmod -R 700 loki_data

# Zabbix DB — PostgreSQL (UID 70 on alpine)
sudo chown -R 70:70 zabbix_db_data
sudo chmod -R 700 zabbix_db_data

# Zabbix Server data
sudo chown -R 1997:1997 zabbix_server_data
sudo chmod -R 700 zabbix_server_data

# ===============================
# 6. Launch stack
# ===============================
echo "📦 Starting containers..."
$DOCKER_COMPOSE up -d

# ===============================
# 7. Create systemd service
# ===============================
echo "⚙️ Creating systemd service..."

sudo sed \
  -e "s|{{WORKING_DIR}}|$WORKING_DIR|g" \
  -e "s|{{DOCKER_COMPOSE}}|$DOCKER_COMPOSE|g" \
  "$TEMPLATE_PATH" | sudo tee "$SERVICE_PATH" > /dev/null

# ===============================
# 8. Enable service
# ===============================
echo "🔄 Enabling service on boot..."

sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME"
sudo systemctl restart "$SERVICE_NAME"

# ===============================
# 9. Completion
# ===============================
echo "-------------------------------------"
echo "✅ Deploy completed successfully!"
echo ""
echo "📊 Access points:"
echo "   Grafana:       http://localhost:${GRAFANA_PORT:-3000}"
echo "   Prometheus:    http://localhost:${PROMETHEUS_PORT:-9090}"
echo "   Zabbix Web:    http://localhost:${ZABBIX_WEB_PORT:-8080}"
echo "   Loki (API):    http://localhost:${LOKI_PORT:-3100}"
echo ""
echo "🔑 Zabbix default login: Admin / zabbix"
echo "   (change immediately after first login)"
