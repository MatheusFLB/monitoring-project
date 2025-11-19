# Projeto de Monitoramento de Dispositivos

## 📋 Visão Geral
Sistema de monitoramento automatizado utilizando Prometheus, Grafana e Node Exporter para coleta e visualização de métricas de dispositivos e servidores.

## 🚀 Configuração Automatizada

### Pré-requisitos
- Docker
- Docker Compose
- Git

### ⚡ Instalação Rápida (Recomendada)

1. **Execute o script de automação:**
```bash
chmod +x setup.sh
sudo ./setup.sh
```

### O script automaticamente:
- ✅ Clona o repositório do projeto
- ✅ Cria a estrutura de pastas necessária
- ✅ Ajusta permissões dos volumes
- ✅ Inicia todos os containers Docker
- ✅ Configura inicialização automática com systemd
- ✅ Importa o dashboard do Node Exporter (ID 1860)

## 🛠️ Configuração Manual (Alternativa)

### 1. Clonar repositório
```bash
git clone https://github.com/seu-usuario/monitoring-app.git
cd monitoring-app
```

### 2. Ajustar permissões
```bash
sudo chown -R 472:472 grafana_data grafana_provisioning
sudo chown -R 65534:65534 prometheus_data
```

### 3. Iniciar serviços
```bash
docker-compose up -d
```

## 🔧 Serviços Disponíveis

| Serviço | URL | Porta | Credenciais |
|---------|-----|-------|-------------|
| **Grafana** | http://localhost:3000 | 3000 | admin/admin |
| **Prometheus** | http://localhost:9090 | 9090 | - |
| **Node Exporter** | http://localhost:9100 | 9100 | - |

## 📊 Dashboard
O dashboard do Node Exporter (ID 1860) é importado automaticamente durante a instalação, fornecendo métricas completas do sistema:
- Uso de CPU e memória
- Utilização de disco
- Estatísticas de rede
- Load average
- E muito mais

## 🔄 Gerenciamento de Serviços

### Comandos Úteis
```bash
# Iniciar serviço
sudo systemctl start monitoring-app.service

# Parar serviço
sudo systemctl stop monitoring-app.service

# Ver status
sudo systemctl status monitoring-app.service

# Reiniciar serviço
sudo systemctl restart monitoring-app.service

# Ver logs dos containers
docker-compose logs -f

# Parar e remover containers
docker-compose down

# Reconstruir e iniciar
docker-compose up -d --build
```

### Verificar se o sistema está funcionando
```bash
# Verificar containers ativos
docker-compose ps

# Verificar logs
docker-compose logs prometheus
docker-compose logs grafana

# Testar acesso
curl http://localhost:3000
curl http://localhost:9090
```

## 🗂️ Estrutura do Projeto
```
monitoring-app/
├── docker-compose.yml          # Orquestração de containers
├── .env                        # Variáveis de ambiente
├── .gitignore                  # Arquivos ignorados pelo Git
├── setup.sh                    # Script de automação principal
├── grafana_data/               # Dados persistentes do Grafana
├── grafana_provisioning/       # Configuração automática do Grafana
│   ├── dashboards/
│   │   └── dashboard.yml
│   └── datasources/
│       └── datasource.yml
├── prometheus/
│   └── prometheus.yml          # Configuração do Prometheus
└── prometheus_data/            # Dados persistentes do Prometheus
```

## 🐛 Solução de Problemas

### Problemas Comuns

1. **Portas já em uso:**
```bash
# Verificar processos usando as portas
sudo netstat -tulpn | grep :3000
sudo netstat -tulpn | grep :9090
```

2. **Problemas de permissão:**
```bash
# Reajustar permissões
sudo chown -R 472:472 grafana_data grafana_provisioning
sudo chown -R 65534:65534 prometheus_data
```

3. **Containers não iniciam:**
```bash
# Verificar logs
docker-compose logs

# Reiniciar containers
docker-compose restart
```

4. **Dashboard não aparece:**
- Acesse http://localhost:3000
- Vá em "+" → Import
- Use o ID: 1860
- Selecione o datasource "Prometheus"

### Verificação de Saúde do Sistema
```bash
# Verificar se todos os serviços estão respondendo
./health-check.sh
```

## 🗑️ Desinstalação

### Remover completamente:
```bash
sudo systemctl stop monitoring-app.service
sudo systemctl disable monitoring-app.service
sudo rm /etc/systemd/system/monitoring-app.service
sudo systemctl daemon-reload
docker-compose down -v
cd ..
sudo rm -rf monitoring-app
```

## 🔄 Atualização

### Para atualizar para a versão mais recente:
```bash
cd monitoring-app
git pull origin main
docker-compose down
docker-compose up -d --build
```

## 📝 Logs e Monitoramento

### Ver logs em tempo real:
```bash
# Todos os serviços
docker-compose logs -f

# Serviço específico
docker-compose logs -f grafana
docker-compose logs -f prometheus
```

### Métricas disponíveis:
- **Node Exporter**: Métricas do sistema operacional
- **Prometheus**: Coleta e armazenamento de métricas
- **Grafana**: Visualização e dashboards

## 🤝 Contribuição
Para contribuir com o projeto:
1. Fork o repositório
2. Crie uma branch para sua feature
3. Commit suas mudanças
4. Push para a branch
5. Abra um Pull Request

## 📞 Suporte
Em caso de problemas:
1. Verifique a seção de Solução de Problemas
2. Consulte os logs dos containers
3. Abra uma issue no repositório

---

**⭐ Dica:** O sistema está configurado para iniciar automaticamente com o sistema operacional através do systemd.