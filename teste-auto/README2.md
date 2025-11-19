# Sistema de Monitoramento

Solução completa para monitorar servidores e infraestrutura, mostrando em tempo real o desempenho e saúde dos sistemas.

## 🚀 Comece em 2 Minutos

### Instalação Automática
```bash
# Baixe e execute o instalador
chmod +x setup.sh
sudo ./setup.sh
```

**Pronto!** O sistema será instalado e configurado automaticamente.

## 📊 O Que Você Vai Ver

Acesse **http://localhost:3000** após a instalação para visualizar:
- ✅ **Uso de CPU e Memória**
- ✅ **Espaço em Disco** 
- ✅ **Tráfego de Rede**
- ✅ **Temperatura do Sistema**
- ✅ **Estatísticas de Processos**

**Login:** admin / admin

## 🛠️ Serviços Incluídos

| Ferramenta | Função | Acesso |
|------------|---------|---------|
| **Grafana** | Painéis visuais | http://localhost:3000 |
| **Prometheus** | Coleta de dados | http://localhost:9090 |
| **Node Exporter** | Métricas do sistema | http://localhost:9100 |

## 📁 Estrutura Simples

```
monitoring-app/
├── docker-compose.yml    # Configuração dos containers
├── prometheus/           # Configurações do Prometheus
├── grafana_provisioning/ # Painéis e fontes de dados
└── setup.sh             # Instalador automático
```

## 🔧 Comandos Úteis

```bash
# Ver status do sistema
sudo systemctl status monitoring-app.service

# Parar o monitoramento
sudo systemctl stop monitoring-app.service

# Reiniciar serviços
sudo systemctl restart monitoring-app.service

# Ver logs
docker-compose logs -f
```

## 🆘 Solução Rápida de Problemas

**Problema:** Não consigo acessar http://localhost:3000
```bash
# Verifique se os serviços estão rodando
docker-compose ps

# Reinicie se necessário
docker-compose restart
```

**Problema:** Dashboard não carrega
- Acesse http://localhost:3000
- Vá em "+" → Import
- Digite o ID: **1860**
- Selecione "Prometheus" como fonte de dados

## 🗑️ Para Remover

```bash
sudo systemctl stop monitoring-app.service
sudo systemctl disable monitoring-app.service
docker-compose down -v
```

---

**💡 Dica:** O sistema inicia automaticamente quando o servidor liga.