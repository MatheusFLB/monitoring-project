#!/bin/bash

# Script de automação para projeto de monitoramento
# Este script clona o repositório e configura o ambiente

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

# URL do repositório (ajuste conforme necessário)
REPO_URL="https://github.com/seu-usuario/monitoring-app.git"
PROJECT_DIR="monitoring-app"

# Clonar repositório
echo "Clonando repositório do projeto..."
if [ -d "$PROJECT_DIR" ]; then
    echo "Diretório $PROJECT_DIR já existe. Atualizando..."
    cd $PROJECT_DIR
    git pull origin main
else
    git clone $REPO_URL $PROJECT_DIR
    cd $PROJECT_DIR
fi

# Verificar se os diretórios necessários existem
echo "Verificando estrutura de pastas..."
DIRECTORIES=("grafana_data" "grafana_provisioning" "prometheus_data")

for dir in "${DIRECTORIES[@]}"; do
    if [ ! -d "$dir" ]; then
        echo "Criando diretório: $dir"
        mkdir -p "$dir"
    fi
done

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
echo "Tentando importar dashboard do Node Exporter..."
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
CURRENT_DIR=$(pwd)

# Verificar caminho do docker-compose
DOCKER_COMPOSE_PATH=$(which docker-compose)

# Criar arquivo de serviço
sudo tee $SERVICE_FILE > /dev/null << EOF
[Unit]
Description=Docker Compose Application Service - Monitoring App
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$CURRENT_DIR
ExecStart=$DOCKER_COMPOSE_PATH up -d
ExecStop=$DOCKER_COMPOSE_PATH down
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
echo ""
echo "Comandos úteis:"
echo "  sudo systemctl start monitoring-app.service    # Iniciar serviço"
echo "  sudo systemctl stop monitoring-app.service     # Parar serviço"
echo "  sudo systemctl status monitoring-app.service   # Ver status"
echo "  docker-compose logs -f                         # Ver logs"
echo ""
echo "Para desinstalar:"
echo "  sudo systemctl stop monitoring-app.service"
echo "  sudo systemctl disable monitoring-app.service"
echo "  sudo rm $SERVICE_FILE"
echo "  docker-compose down -v"
echo "  cd .. && sudo rm -rf $PROJECT_DIR"