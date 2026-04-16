#!/usr/bin/env bash
# =============================================================================
# deploy.sh — Script de deploy automatizado do Monitoring Stack
# =============================================================================
# Este script configura e inicia toda a stack de monitoramento:
#   1. Verifica dependências (Docker, Docker Compose)
#   2. Avalia recursos do host (RAM)
#   3. Cria o arquivo .env com senhas e portas
#   4. Cria diretórios persistentes com permissões corretas
#   5. Inicia os containers em sequência
#   6. Inicializa o banco do Zabbix (se necessário)
#   7. Configura serviço systemd para boot automático
#
# Uso:
#   chmod +x deploy.sh
#   sudo ./deploy.sh
#
# Pré-requisitos:
#   - Docker e Docker Compose instalados
#   - Acesso root (sudo)
#   - 6 GB RAM mínimo (8 GB+ recomendado)
# =============================================================================
set -e  # Interrompe execução em caso de erro

# --- Constantes do projeto ---
SERVICE_NAME="monitoring-app.service"
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}"
TEMPLATE_PATH="./systemd/monitoring-app.service.template"
ENV_FILE=".env"

echo "🚀 Starting Monitoring Stack deploy"
echo "-------------------------------------"

# =============================================================================
# 1. Verificação de dependências
# =============================================================================
# Garante que Docker e Docker Compose estão instalados antes de prosseguir.

command -v docker >/dev/null 2>&1 || {
  echo "❌ Docker is not installed"
  exit 1
}

# Suporta tanto docker-compose (v1) quanto docker compose (v2)
if command -v docker-compose >/dev/null 2>&1; then
  DOCKER_COMPOSE="$(which docker-compose)"
elif docker compose version >/dev/null 2>&1; then
  DOCKER_COMPOSE="docker compose"
else
  echo "❌ Docker Compose not found"
  exit 1
fi

# =============================================================================
# 1.5. Verificação de recursos
# =============================================================================
# A stack completa consome ~3-4 GB de RAM em idle. Alerta se o host tem < 4 GB.

TOTAL_RAM_MB=$(awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo)
if [[ "$TOTAL_RAM_MB" -lt 4096 ]]; then
  echo "⚠️  Warning: this host has only ${TOTAL_RAM_MB} MB RAM."
  echo "   The full stack works best with ≥ 6 GB. Expect higher swap usage."
fi

# =============================================================================
# 2. Configuração do .env
# =============================================================================
# O arquivo .env contém todas as senhas e portas usadas pelo docker-compose.yml.
# Se já existe, pergunta se deseja reutilizar. Se não, cria interativamente.

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

  # --- Grafana / Prometheus / Node Exporter ---
  read -s -p "Grafana admin password: " GF_SECURITY_ADMIN_PASSWORD
  echo
  read -p "Grafana port (e.g., 3000): " GRAFANA_PORT
  read -p "Prometheus port (e.g., 9090): " PROMETHEUS_PORT
  read -p "Node Exporter port (e.g., 9100): " NODE_EXPORTER_PORT

  # --- Zabbix ---
  echo "-------------------------------------"
  echo "📝 Zabbix configuration"
  # Gera senha segura automaticamente para o banco PostgreSQL do Zabbix
  ZABBIX_DB_PASSWORD=$(openssl rand -base64 18 2>/dev/null || head -c 18 /dev/urandom | base64)
  echo "   (Zabbix DB password generated automatically)"
  read -p "Zabbix Web port (e.g., 8080): " ZABBIX_WEB_PORT
  read -p "Zabbix Server port (e.g., 10051): " ZABBIX_SERVER_PORT
  read -p "Zabbix agent hostname for this host (e.g., monitoring-host): " ZABBIX_AGENT_HOSTNAME
  read -p "Timezone (e.g., America/Sao_Paulo): " TZ

  # --- Loki ---
  echo "-------------------------------------"
  echo "📝 Loki configuration"
  read -p "Loki port (e.g., 3100): " LOKI_PORT

  # Gera o arquivo .env com todos os valores coletados
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

  # Protege o arquivo .env (contém senhas)
  chmod 600 "$ENV_FILE"
  echo "✅ .env file created successfully"
fi

# -----------------------------------------------------------------------------
# Função auxiliar: lê um valor do .env com fallback para default
# -----------------------------------------------------------------------------
get_env_value() {
  local key="$1"
  local default_value="$2"
  local value
  value=$(grep -E "^${key}=" "$ENV_FILE" | tail -n1 | cut -d= -f2-)
  if [[ -n "$value" ]]; then
    printf '%s' "$value"
  else
    printf '%s' "$default_value"
  fi
}

# -----------------------------------------------------------------------------
# Função: aguarda PostgreSQL ficar pronto para conexões
# -----------------------------------------------------------------------------
wait_for_postgres() {
  local db_name="$1"
  local db_user="$2"
  local attempt=1
  local max_attempts=30

  echo "⏳ Waiting for PostgreSQL to become ready..."

  until sudo docker exec zabbix-db pg_isready -U "$db_user" -d "$db_name" >/dev/null 2>&1; do
    if [[ "$attempt" -ge "$max_attempts" ]]; then
      echo "❌ PostgreSQL did not become ready in time"
      exit 1
    fi
    attempt=$((attempt + 1))
    sleep 2
  done
}

# -----------------------------------------------------------------------------
# Função: verifica se o schema do Zabbix já foi criado
# -----------------------------------------------------------------------------
zabbix_schema_is_ready() {
  local db_name="$1"
  local db_user="$2"
  local users_count
  users_count=$(sudo docker exec zabbix-db psql -U "$db_user" -d "$db_name" \
    -tAc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users';" \
    2>/dev/null | tr -d '[:space:]')
  [[ "$users_count" == "1" ]]
}

# -----------------------------------------------------------------------------
# Função: inicializa o schema do Zabbix no PostgreSQL
# -----------------------------------------------------------------------------
initialize_zabbix_schema() {
  local db_name="$1"
  local db_user="$2"

  echo "🗄️ Initializing Zabbix database schema..."
  sudo docker run --rm \
    --network monitoring-network \
    zabbix/zabbix-server-pgsql:ubuntu-7.0-latest \
    sh -c 'zcat /usr/share/doc/zabbix-server-postgresql/create.sql.gz' \
    | sudo docker exec -i zabbix-db psql -U "$db_user" -d "$db_name" >/dev/null
}

# Lê valores do .env para usar nos passos seguintes
ZABBIX_DB_NAME_VALUE="$(get_env_value ZABBIX_DB_NAME zabbix)"
ZABBIX_DB_USER_VALUE="$(get_env_value ZABBIX_DB_USER zabbix)"
GRAFANA_PORT_VALUE="$(get_env_value GRAFANA_PORT 3000)"
PROMETHEUS_PORT_VALUE="$(get_env_value PROMETHEUS_PORT 9090)"
ZABBIX_WEB_PORT_VALUE="$(get_env_value ZABBIX_WEB_PORT 8080)"
LOKI_PORT_VALUE="$(get_env_value LOKI_PORT 3100)"

# =============================================================================
# 3. Diretório do projeto
# =============================================================================
WORKING_DIR="$(pwd)"

echo "📁 Project: $WORKING_DIR"
echo "🐳 Docker Compose: $DOCKER_COMPOSE"

# =============================================================================
# 4. Criação de diretórios persistentes
# =============================================================================
# Cria a estrutura de diretórios para dados persistentes dos serviços.
# Os dados sobrevivem a recriações de containers.

echo "📂 Ensuring persistent directories exist..."
mkdir -p \
  data/grafana \
  data/prometheus \
  data/loki \
  data/zabbix-db \
  data/zabbix-server

# =============================================================================
# 5. Ajuste de permissões dos volumes
# =============================================================================
# Cada serviço roda com um UID específico dentro do container.
# Os diretórios precisam pertencer ao UID correto para escrita.

echo "🔐 Adjusting volume permissions..."

# Grafana roda como UID 472 (grafana user)
sudo chown -R 472:472 data/grafana
sudo chmod -R 700 data/grafana

# Prometheus roda como UID 65534 (nobody)
sudo chown -R 65534:65534 data/prometheus
sudo chmod -R 700 data/prometheus

# Loki roda como UID 10001 (loki default)
sudo chown -R 10001:10001 data/loki
sudo chmod -R 700 data/loki

# PostgreSQL no Alpine roda como UID 70
sudo chown -R 70:70 data/zabbix-db
sudo chmod -R 700 data/zabbix-db

# Zabbix Server roda como UID 1997
sudo chown -R 1997:1997 data/zabbix-server
sudo chmod -R 700 data/zabbix-server

# Garante que o Grafana pode ler os arquivos de provisioning
sudo chown -R 472:472 config/grafana
sudo chmod -R 755 config/grafana

# =============================================================================
# 6. Inicialização dos containers
# =============================================================================
# Inicia em duas fases:
#   Fase 1: Serviços base (exporters, Prometheus, Grafana, Loki, DB)
#   Fase 2: Serviços Zabbix (após DB estar pronto e schema criado)

echo "📦 Starting containers (phase 1: base services)..."
$DOCKER_COMPOSE up -d \
  node-exporter-instancia1 \
  prometheus-instancia1 \
  grafana-instancia1 \
  loki promtail \
  zabbix-db

# Aguarda PostgreSQL aceitar conexões antes de iniciar Zabbix Server
wait_for_postgres "$ZABBIX_DB_NAME_VALUE" "$ZABBIX_DB_USER_VALUE"

# Inicializa o schema do Zabbix se for a primeira execução
if ! zabbix_schema_is_ready "$ZABBIX_DB_NAME_VALUE" "$ZABBIX_DB_USER_VALUE"; then
  initialize_zabbix_schema "$ZABBIX_DB_NAME_VALUE" "$ZABBIX_DB_USER_VALUE"
fi

echo "📦 Starting containers (phase 2: Zabbix services)..."
$DOCKER_COMPOSE up -d zabbix-server zabbix-agent zabbix-web

# =============================================================================
# 7. Configuração do serviço systemd
# =============================================================================
# Cria um serviço systemd para iniciar a stack automaticamente no boot.
# O template usa placeholders que são substituídos pelo caminho real.

echo "⚙️ Creating systemd service..."

sudo sed \
  -e "s|{{WORKING_DIR}}|$WORKING_DIR|g" \
  -e "s|{{DOCKER_COMPOSE}}|$DOCKER_COMPOSE|g" \
  "$TEMPLATE_PATH" | sudo tee "$SERVICE_PATH" > /dev/null

# =============================================================================
# 8. Habilita serviço no boot
# =============================================================================
echo "🔄 Enabling service on boot..."

sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME"
sudo systemctl restart "$SERVICE_NAME"

# =============================================================================
# 9. Conclusão
# =============================================================================
echo "-------------------------------------"
echo "✅ Deploy completed successfully!"
echo ""
echo "📊 Access points:"
echo "   Grafana:       http://localhost:${GRAFANA_PORT_VALUE}"
echo "   Prometheus:    http://localhost:${PROMETHEUS_PORT_VALUE}"
echo "   Zabbix Web:    http://localhost:${ZABBIX_WEB_PORT_VALUE}"
echo "   Loki (API):    http://localhost:${LOKI_PORT_VALUE}"
echo ""
echo "🔑 Zabbix default login: Admin / zabbix"
echo "   (change immediately after first login)"
