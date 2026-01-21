#!/usr/bin/env bash
set -e

SERVICE_NAME="monitoring-app.service"
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}"
TEMPLATE_PATH="./systemd/monitoring-app.service.template"
ENV_EXAMPLE=".env.example"
ENV_FILE=".env"

echo "🚀 Iniciando deploy do Monitoring Stack"
echo "-------------------------------------"

# ===============================
# 1. Verificar dependências
# ===============================
command -v docker >/dev/null 2>&1 || {
  echo "❌ Docker não está instalado"
  exit 1
}

if command -v docker-compose >/dev/null 2>&1; then
  DOCKER_COMPOSE="$(which docker-compose)"
elif docker compose version >/dev/null 2>&1; then
  DOCKER_COMPOSE="docker compose"
else
  echo "❌ Docker Compose não encontrado"
  exit 1
fi

# ===============================
# 2. Configuração do .env
# ===============================
if [[ -f "$ENV_FILE" ]]; then
  echo "⚠️ Arquivo .env já existe."
  read -p "Deseja reutilizá-lo? (s/n): " reuse_env
  if [[ "$reuse_env" != "s" ]]; then
    rm -f "$ENV_FILE"
  fi
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "📝 Criando arquivo .env"
  echo "-------------------------------------"

  read -s -p "Senha do admin do Grafana: " GF_SECURITY_ADMIN_PASSWORD
  echo
  read -p "Porta do Grafana (ex: 3000): " GRAFANA_PORT
  read -p "Porta do Prometheus (ex: 9090): " PROMETHEUS_PORT
  read -p "Porta do Node Exporter (ex: 9100): " NODE_EXPORTER_PORT

  cat <<EOF > "$ENV_FILE"
GF_SECURITY_ADMIN_PASSWORD=$GF_SECURITY_ADMIN_PASSWORD
GRAFANA_PORT=$GRAFANA_PORT
PROMETHEUS_PORT=$PROMETHEUS_PORT
NODE_EXPORTER_PORT=$NODE_EXPORTER_PORT
EOF

  echo "✅ Arquivo .env criado com sucesso"
fi

# ===============================
# 3. Diretório do projeto
# ===============================
WORKING_DIR="$(pwd)"

echo "📁 Projeto: $WORKING_DIR"
echo "🐳 Docker Compose: $DOCKER_COMPOSE"

# ===============================
# 4. Ajustar permissões
# ===============================
echo "🔐 Ajustando permissões dos volumes..."

sudo chown -R 472:472 grafana_data grafana_provisioning
sudo chown -R 65534:65534 prometheus_data

# ===============================
# 5. Subir stack
# ===============================
echo "📦 Subindo containers..."
$DOCKER_COMPOSE up -d

# ===============================
# 6. Criar serviço systemd
# ===============================
echo "⚙️ Criando serviço systemd..."

sudo sed \
  -e "s|{{WORKING_DIR}}|$WORKING_DIR|g" \
  -e "s|{{DOCKER_COMPOSE}}|$DOCKER_COMPOSE|g" \
  "$TEMPLATE_PATH" | sudo tee "$SERVICE_PATH" > /dev/null

# ===============================
# 7. Ativar serviço
# ===============================
echo "🔄 Ativando serviço no boot..."

sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME"
sudo systemctl restart "$SERVICE_NAME"

# ===============================
# 8. Finalização
# ===============================
echo "-------------------------------------"
echo "✅ Deploy concluído com sucesso!"
echo "📊 Grafana: http://localhost:${GRAFANA_PORT}"
echo "📈 Prometheus: http://localhost:${PROMETHEUS_PORT}"
