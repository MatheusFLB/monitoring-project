#!/bin/bash

# Variáveis
GIT_REPO="https://github.com/seu-usuario/seu-repositorio.git"
PROJECT_DIR="$PWD/monitoring-app"
SERVICE_NAME="monitoring-app"

# Função para verificar se um comando foi bem-sucedido
check_success() {
    if [ $? -ne 0 ]; then
        echo "Erro: $1"
        exit 1
    fi
}

# Atualizar e instalar dependências (docker e docker-compose) se necessário
echo "Verificando dependências..."

if ! command -v docker &> /dev/null; then
    echo "Docker não encontrado. Instalando Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    check_success "Falha na instalação do Docker."
fi

if ! command -v docker-compose &> /dev/null; then
    echo "Docker Compose não encontrado. Instalando Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    check_success "Falha na instalação do Docker Compose."
fi

# Criar a estrutura de pastas
echo "Criando estrutura de pastas..."
mkdir -p $PROJECT_DIR/grafana_provisioning/dashboards
mkdir -p $PROJECT_DIR/grafana_provisioning/datasources
mkdir -p $PROJECT_DIR/prometheus
mkdir -p $PROJECT_DIR/grafana_data
mkdir -p $PROJECT_DIR/prometheus_data

check_success "Falha ao criar pastas."

# Clonar o repositório (ou baixar os arquivos)
echo "Clonando repositório..."
git clone $GIT_REPO $PROJECT_DIR
check_success "Falha ao clonar o repositório."

# Ajustar permissões
echo "Ajustando permissões..."
sudo chown -R 472:472 $PROJECT_DIR/grafana_data
sudo chown -R 472:472 $PROJECT_DIR/grafana_provisioning
sudo chown -R 65534:65534 $PROJECT_DIR/prometheus_data

check_success "Falha ao ajustar permissões."

# Configurar systemd
echo "Configurando systemd..."

# Obter o caminho absoluto do projeto
WORKING_DIR=$PROJECT_DIR

# Obter o caminho do docker-compose
DOCKER_COMPOSE_PATH=$(which docker-compose)

# Criar o arquivo de serviço
sudo tee /etc/systemd/system/${SERVICE_NAME}.service > /dev/null <<EOF
[Unit]
Description=Docker Compose Application Service
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$WORKING_DIR
ExecStart=$DOCKER_COMPOSE_PATH up -d
ExecStop=$DOCKER_COMPOSE_PATH down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

# Recarregar systemd
sudo systemctl daemon-reload

# Habilitar o serviço para iniciar no boot
sudo systemctl enable ${SERVICE_NAME}.service

# Iniciar o serviço
sudo systemctl start ${SERVICE_NAME}.service

# Verificar status
sudo systemctl status ${SERVICE_NAME}.service

echo "Configuração concluída!"