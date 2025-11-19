#!/bin/bash

# Script de automação para projeto de monitoramento
# Este script configura toda a estrutura e serviços necessários

set -e  # Para o script em caso de erro

echo "=== Iniciando configuração do sistema de monitoramento ==="

# Verificar dependências
if ! command -v docker &> /dev/null; then
    echo "Docker não encontrado. Por favor, instale o Docker primeiro."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "Docker Compose não encontrado. Por favor, instale o Docker Compose primeiro."
    exit 1
fi

if ! command -v git &> /dev/null; then
    echo "Git não encontrado. Por favor, instale o Git primeiro."
    exit 1
fi

# Criar estrutura de pastas
echo "Criando estrutura de pastas..."
mkdir -p monitoring-app
cd monitoring-app
mkdir -p grafana_data
mkdir -p grafana_provisioning/dashboards
mkdir -p grafana_provisioning/datasources
mkdir -p prometheus
mkdir -p prometheus_data

# Clonar repositório (substitua pela URL real do seu repositório)
echo "Clonando repositório do projeto..."
# GIT_REPO="https://github.com/seu-usuario/monitoring-app.git"
# git clone $GIT_REPO .
# Ou copiar arquivos manualmente se não houver repositório

# Criar arquivos de configuração básicos se não existirem
echo "Criando arquivos de configuração..."

# docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - ./prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=200h'
      - '--web.enable-lifecycle'
    restart: unless-stopped
    ports:
      - "9090:9090"
    networks:
      - monitoring

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    volumes:
      - ./grafana_data:/var/lib/grafana
      - ./grafana_provisioning/dashboards:/etc/grafana/provisioning/dashboards
      - ./grafana_provisioning/datasources:/etc/grafana/provisioning/datasources
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    restart: unless-stopped
    ports:
      - "3000:3000"
    networks:
      - monitoring

  node_exporter:
    image: prom/node-exporter:latest
    container_name: node_exporter
    restart: unless-stopped
    ports:
      - "9100:9100"
    networks:
      - monitoring
    command:
      - '--path.rootfs=/host'
    pid: host
    volumes:
      - /:/host:ro,rslave

networks:
  monitoring:
    driver: bridge
EOF

# prometheus.yml
cat > prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['node_exporter:9100']
EOF

# datasource.yml
cat > grafana_provisioning/datasources/datasource.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
EOF

# dashboard.yml
cat > grafana_provisioning/dashboards/dashboard.yml << 'EOF'
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
EOF

# .env
cat > .env << 'EOF'
GF_SECURITY_ADMIN_PASSWORD=admin
EOF

# .gitignore
cat > .gitignore << 'EOF'
grafana_data/
prometheus_data/
.env
EOF

# Ajustar permissões
echo "Ajustando permissões..."
sudo chown -R 472:472 grafana_data
sudo chown -R 472:472 grafana_provisioning
sudo chown -R 65534:65534 prometheus_data

# Iniciar os containers
echo "Iniciando containers Docker..."
docker-compose up -d

echo "Aguardando serviços inicializarem..."
sleep 30

# Importar dashboard do Node Exporter
echo "Importando dashboard do Node Exporter..."
DASHBOARD_ID=1860
GRAFANA_URL="http://localhost:3000"
GRAFANA_USER="admin"
GRAFANA_PASSWORD="admin"

# Função para importar dashboard
import_dashboard() {
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{
            \"dashboard\": $(curl -s https://grafana.com/api/dashboards/${DASHBOARD_ID}/revisions/latest/download),
            \"overwrite\": true,
            \"inputs\": [
                {
                    \"name\": \"DS_PROMETHEUS\",
                    \"type\": \"datasource\",
                    \"pluginId\": \"prometheus\",
                    \"value\": \"Prometheus\"
                }
            ]
        }" \
        "${GRAFANA_URL}/api/dashboards/import" \
        -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}"
}

# Tentar importar o dashboard
if import_dashboard | grep -q '"slug"'; then
    echo "Dashboard importado com sucesso!"
else
    echo "Aviso: Não foi possível importar o dashboard automaticamente."
    echo "Você pode importar manualmente:"
    echo "1. Acesse http://localhost:3000"
    echo "2. Login: admin/admin"
    echo "3. Vá em '+' → Import"
    echo "4. Use o ID: 1860"
fi

# Configurar serviço systemd
echo "Configurando inicialização automática..."
SERVICE_FILE="/etc/systemd/system/monitoring-app.service"
PROJECT_DIR=$(pwd)

# Criar arquivo de serviço
sudo tee $SERVICE_FILE > /dev/null << EOF
[Unit]
Description=Docker Compose Application Service - Monitoring App
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$PROJECT_DIR
ExecStart=$(which docker-compose) up -d
ExecStop=$(which docker-compose) down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

# Recarregar e ativar serviço
sudo systemctl daemon-reload
sudo systemctl enable monitoring-app.service

echo "=== Configuração concluída com sucesso! ==="
echo ""
echo "Serviços disponíveis:"
echo "- Grafana: http://localhost:3000 (admin/admin)"
echo "- Prometheus: http://localhost:9090"
echo "- Node Exporter: http://localhost:9100"
echo ""
echo "O serviço foi configurado para iniciar automaticamente na inicialização do sistema."
echo "Comandos úteis:"
echo "  sudo systemctl start monitoring-app.service    # Iniciar serviço"
echo "  sudo systemctl stop monitoring-app.service     # Parar serviço"
echo "  sudo systemctl status monitoring-app.service   # Ver status"
echo "  docker-compose logs -f                         # Ver logs"
echo ""
echo "Para desinstalar, execute:"
echo "  sudo systemctl stop monitoring-app.service"
echo "  sudo systemctl disable monitoring-app.service"
echo "  sudo rm $SERVICE_FILE"
echo "  docker-compose down -v"
echo "  cd .. && sudo rm -rf monitoring-app"