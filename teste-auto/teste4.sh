#!/bin/bash

# Script básico de automação para projeto de monitoramento

set -e

echo "=== Configuração do Sistema de Monitoramento ==="

# Verificar dependências
for cmd in docker docker-compose git; do
    if ! command -v $cmd &> /dev/null; then
        echo "Erro: $cmd não encontrado. Instale primeiro."
        exit 1
    fi
done

# Configurações
REPO_URL="https://github.com/seu-usuario/monitoring-app.git"
PROJECT_DIR="monitoring-app"

# Clonar/atualizar repositório
echo "Clonando repositório..."
if [ -d "$PROJECT_DIR" ]; then
    cd $PROJECT_DIR
    git pull
else
    git clone $REPO_URL $PROJECT_DIR
    cd $PROJECT_DIR
fi

# Criar diretórios se não existirem
mkdir -p grafana_data grafana_provisioning prometheus_data

# Ajustar permissões
echo "Ajustando permissões..."
sudo chown -R 472:472 grafana_data grafana_provisioning
sudo chown -R 65534:65534 prometheus_data

# Iniciar serviços
echo "Iniciando containers..."
docker-compose up -d

# Configurar systemd
echo "Configurando inicialização automática..."
sudo tee /etc/systemd/system/monitoring-app.service > /dev/null << EOF
[Unit]
Description=Monitoring App Docker Compose
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$(pwd)
ExecStart=$(which docker-compose) up -d
ExecStop=$(which docker-compose) down

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable monitoring-app.service

echo "=== Concluído! ==="
echo "Grafana: http://localhost:3000 (admin/admin)"
echo "Serviço systemd: monitoring-app.service"