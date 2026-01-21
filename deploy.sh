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

  read -s -p "Grafana admin password: " GF_SECURITY_ADMIN_PASSWORD
  echo
  read -p "Grafana port (e.g., 3000): " GRAFANA_PORT
  read -p "Prometheus port (e.g., 9090): " PROMETHEUS_PORT
  read -p "Node Exporter port (e.g., 9100): " NODE_EXPORTER_PORT

  cat <<EOF > "$ENV_FILE"
GF_SECURITY_ADMIN_PASSWORD=$GF_SECURITY_ADMIN_PASSWORD
GRAFANA_PORT=$GRAFANA_PORT
PROMETHEUS_PORT=$PROMETHEUS_PORT
NODE_EXPORTER_PORT=$NODE_EXPORTER_PORT
EOF

  echo "✅ .env file created successfully"
fi

# ===============================
# 3. Project directory
# ===============================
WORKING_DIR="$(pwd)"

echo "📁 Project: $WORKING_DIR"
echo "🐳 Docker Compose: $DOCKER_COMPOSE"

# ===============================
# 4. Adjust permissions
# ===============================
echo "🔐 Adjusting volume permissions..."

sudo chown -R 472:472 grafana_data grafana_provisioning
sudo chmod -R 700 grafana_data grafana_provisioning
sudo chown -R 65534:65534 prometheus_data
sudo chmod -R 700 prometheus_data

# ===============================
# 5. Launch stack
# ===============================
echo "📦 Starting containers..."
$DOCKER_COMPOSE up -d

# ===============================
# 6. Create systemd service
# ===============================
echo "⚙️ Creating systemd service..."

sudo sed \
  -e "s|{{WORKING_DIR}}|$WORKING_DIR|g" \
  -e "s|{{DOCKER_COMPOSE}}|$DOCKER_COMPOSE|g" \
  "$TEMPLATE_PATH" | sudo tee "$SERVICE_PATH" > /dev/null

# ===============================
# 7. Enable service
# ===============================
echo "🔄 Enabling service on boot..."

sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME"
sudo systemctl restart "$SERVICE_NAME"

# ===============================
# 8. Completion
# ===============================
echo "-------------------------------------"
echo "✅ Deploy completed successfully!"
